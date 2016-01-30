def translate_elem_name(name)
  case name
  when 'listing'
    'pre'
  when 'identifier', 'glob'
    'i'
  else
    name
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

element_stack = []
INDENTATION = 2

File.read(ARGV[0]).lines.each do |line|
  case line
  when /^\s+$/ # blank line
    # ignore
  when /^(\s*)([a-z0-9-]+)(\[.*?\])?\.\s*$/ # empty element
    indentation = $1
    element = $2
    options = $3

    element_stack << element
    $stdout << "<#{translate_elem_name(element)}>"
    $stdout << "\n\n"
  when /^(\s*)([a-z0-9-]+)(\[.*?\])?\. (.*)$/ # element with inline content
    indentation = $1
    element = $2
    options = $3
    data = $4

    while element_stack.size * INDENTATION > indentation.size
      elem = element_stack.pop
      $stdout << "</#{translate_elem_name(elem)}>"
      $stdout << "\n"
    end

    $stdout << "<#{translate_elem_name(element)}>"
    parse(data)
    $stdout << "</#{translate_elem_name(element)}>"
    $stdout << "\n\n"
  when /^(\s*)(.*)$/
    indentation = $1
    data = $2

    while element_stack.size * INDENTATION > indentation.size
      elem = element_stack.pop
      $stdout << "</#{translate_elem_name(elem)}>"
      $stdout << "\n"
    end

    $stdout << data
    $stdout << "\n"
  end
end

element_stack.reverse_each do |elem|
  $stdout << "</#{translate_elem_name(elem)}>"
  $stdout << "\n"
end
