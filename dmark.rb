def translate_elem_name(name)
  case name
  when 'listing'
    'pre'
  when 'firstterm', 'identifier', 'glob', 'emph', 'filename', 'class'
    'i'
  when 'command'
    'code'
  when 'p', 'dl', 'dt', 'dd', 'code', 'h1', 'h2', 'h3', 'ul', 'li'
    name
  else
    raise "Cannot translate #{name}"
  end
end

#########################

class Token
  def to_s
    raise NotImplementedError
  end
end

class TextToken < Token
  attr_reader :text

  def initialize(text:)
    @text = text
  end

  def to_s
    @text
  end
end

class AbstractTagToken < Token
  attr_reader :name

  def initialize(name:)
    @name = name
  end
end

class TagBeginToken < AbstractTagToken
  def to_s
    "<#{translate_elem_name(name)}>"
  end
end

class TagEndToken < AbstractTagToken
  def to_s
    "</#{translate_elem_name(name)}>"
  end
end

#########################

def append_text(out, text)
  if out.empty? || !out.last.is_a?(TextToken)
    out << TextToken.new(text: text)
  else
    out.last.text << text
  end
end

def lex(data)
  stack = []
  state = :root
  tokens = []
  name = ''

  data.chars.each do |char|
    case state
    when :root
      case char
      when '%'
        state = :after_pct
      when '{'
        # FIXME: remove this handling
        stack << [:raw, '}']
        append_text(tokens, '{')
      when '}'
        if stack.empty?
          raise "Stack empty"
        else
          data = stack.pop
          case data.first
          when :raw
            append_text(tokens, data.last)
          when :elem
            tokens << TagEndToken.new(name: data.last)
          else
            raise "Unexpected entry on stack: #{data.inspect}"
          end
        end
      else
        append_text(tokens, char)
      end
    when :after_pct
      case char
      when 'a'..'z', '0'..'9', '-'
        name << char
      when '%' # escaped
        state = :root
        append_text(tokens, '%')
      when '{'
        state = :root
        stack << [:elem, name]
        tokens << TagBeginToken.new(name: name)
        name = ''
      else
        raise "Unexpected char: #{char}"
      end
    else
      raise "Unexpected state: #{state.inspect}"
    end
  end

  tokens
end

class Lexer
  INDENTATION = 2

  def initialize(string)
    @string = string

    @element_stack = []
    @tokens = []
    @pending_blanks = 0
  end

  def run
    @string.lines.each do |line|
      case line
      when /^\s+$/
        # blank line
        @pending_blanks += 1
      when /^(\s*)([a-z0-9-]+)(\[.*?\])?\.\s*$/
        # empty element
        indentation = $1
        element = $2
        options = $3

        unwind_stack_until(indentation.size)

        @element_stack << element
        @tokens << TagBeginToken.new(name: element)
      when /^(\s*)([a-z0-9-]+)(\[.*?\])?\. (.*)$/
        # element with inline content
        indentation = $1
        element = $2
        options = $3
        data = $4

        unwind_stack_until(indentation.size)

        @tokens << TagBeginToken.new(name: element)
        @tokens.concat(lex(data))
        @tokens << TagEndToken.new(name: element)
      when /^(\s*)(.*)$/
        # other line (e.g. data)
        indentation = $1
        data = $2

        unwind_stack_until(indentation.size)

        if @element_stack.empty?
          raise "Can’t insert raw data at root level"
        end

        append_text(@tokens, data + "\n")
      end
    end

    unwind_stack_until(0)

    @tokens
  end

  private

  def unwind_stack_until(num)
    while @element_stack.size * INDENTATION > num
      elem = @element_stack.pop

      @tokens << TagEndToken.new(name: elem)
    end

    append_text(@tokens, "\n" * @pending_blanks)
    @pending_blanks = 0
  end
end

tokens = Lexer.new(File.read(ARGV[0])).run
puts tokens.join('')
