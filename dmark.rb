def translate_elem_name(name)
  case name
  when 'listing'
    'pre'
  when 'firstterm', 'identifier', 'glob', 'emph', 'filename', 'class'
    'i'
  when 'command'
    'code'
  when 'p', 'dl', 'dt', 'dd', 'code', 'h2', 'h3', 'ul', 'li'
    name
  else
    raise "Cannot translate #{name}"
  end
end

def parse(data)
  stack = []
  state = :root
  out = $stdout
  name = ''

  data.chars.each do |char|
    case state
    when :root
      case char
      when '%'
        state = :after_pct
      when '{'
        stack << [:raw, '}']
        out << '{'
      when '}'
        if stack.empty?
          raise "Stack empty"
        else
          data = stack.pop
          case data.first
          when :raw
            out << data.last
          when :elem
            out << "</#{translate_elem_name(data.last)}>"
          else
            raise "Unexpected entry on stack: #{data.inspect}"
          end
        end
      else
        out << char
      end
    when :after_pct
      case char
      when 'a'..'z', '0'..'9', '-'
        name << char
      when '%' # escaped
        state = :root
        out << '%'
      when '{'
        state = :root
        stack << [:elem, name]
        out << "<#{translate_elem_name(name)}>"
        name = ''
      else
        raise "Unexpected char: #{char}"
      end
    else
      raise "Unexpected state: #{state.inspect}"
    end
  end

  out
end

INDENTATION = 2

$element_stack = []
$pending_blanks = 0

def unwind_stack_until(num)
  while $element_stack.size * INDENTATION > num
    elem = $element_stack.pop
    $stdout << "</#{translate_elem_name(elem)}>"
    $stdout << "\n"
  end

  $pending_blanks.times { $stdout << "\n" }
  $pending_blanks = 0
end

File.read(ARGV[0]).lines.each do |line|
  case line
  when /^\s+$/
    # blank line
    $pending_blanks += 1
  when /^(\s*)([a-z0-9-]+)(\[.*?\])?\.\s*$/
    # empty element
    indentation = $1
    element = $2
    options = $3

    unwind_stack_until(indentation.size)

    $element_stack << element
    $stdout << "<#{translate_elem_name(element)}>"
  when /^(\s*)([a-z0-9-]+)(\[.*?\])?\. (.*)$/
    # element with inline content
    indentation = $1
    element = $2
    options = $3
    data = $4

    unwind_stack_until(indentation.size)

    $stdout << "<#{translate_elem_name(element)}>"
    parse(data)
    $stdout << "</#{translate_elem_name(element)}>"
    $stdout << "\n\n"
  when /^(\s*)(.*)$/
    # other line (e.g. data)
    indentation = $1
    data = $2

    unwind_stack_until(indentation.size)

    if $element_stack.empty?
      raise "Can’t insert raw data at root level"
    end

    $stdout << data
    $stdout << "\n"
  end
end

unwind_stack_until(0)
