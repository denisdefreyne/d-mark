class MyHTMLTranslator
  def initialize(tree)
    @tree = tree
  end

  def run
    ''.tap { |io| handle(@tree, io) }
  end

  private

  def handle(node, io)
    case node
    when RootNode
      node.children.each { |child| handle(child, io) }
    when TextNode
      io << node.text
    when ElementNode
      io << "<#{translate_elem_name(node.name)}>"
      node.children.each { |child| handle(child, io) }
      io << "</#{translate_elem_name(node.name)}>"
    end
  end

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
end

#########################

class Node
  attr_reader :children

  def initialize
    @children = []
  end

  def inspect(indent = 0)
    'Node()'
  end
end

class RootNode < Node
  def inspect(indent = 0)
    io = ''
    io << '  ' * indent
    io << 'Root('
    io << "\n" if children.any?
    children.each { |c| io << c.inspect(indent + 1) }
    io << '  ' * indent if children.any?
    io << ')'
    io << "\n"
    io
  end
end

class TextNode < Node
  attr_reader :text

  def initialize(text:)
    super()
    @text = text
  end

  def inspect(indent = 0)
    io = ''
    io << '  ' * indent
    io << 'Text('
    io << @text.inspect
    io << "\n" if children.any?
    children.each { |c| io << c.inspect(indent + 1) }
    io << '  ' * indent if children.any?
    io << ')'
    io << "\n"
    io
  end
end

class ElementNode < Node
  attr_reader :name

  def initialize(name:)
    super()
    @name = name
  end

  def inspect(indent = 0)
    io = ''
    io << '  ' * indent
    io << 'Element('
    io << @name
    io << "\n" if children.any?
    children.each { |c| io << c.inspect(indent + 1) }
    io << '  ' * indent if children.any?
    io << ')'
    io << "\n"
    io
  end
end

#########################

class Parser
  def initialize(tokens)
    @tokens = tokens

    @root_node = RootNode.new
  end

  def run
    node_stack = [@root_node]

    @tokens.each do |token|
      case token
      when TextToken
        node_stack.last.children << TextNode.new(text: token.text)
      when TagBeginToken
        new_node = ElementNode.new(name: token.name)
        node_stack.last.children << new_node
        node_stack.push(new_node)
      when TagEndToken
        node_stack.pop
      end
    end

    @root_node
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
    "Text(#{@text.inspect})"
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
    "TagBegin(#{name.inspect})"
  end
end

class TagEndToken < AbstractTagToken
  def to_s
    "TagEnd(#{name.inspect})"
  end
end

#########################

class Lexer
  INDENTATION = 2

  def initialize(string)
    @string = string

    @element_stack = []
    @tokens = []
    @pending_blanks = 0
  end

  def run
    @string.lines.each_with_index do |line, line_nr|
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
        @tokens.concat(lex_inline(data, line_nr + 1))
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

  def append_text(out, text)
    if out.empty? || !out.last.is_a?(TextToken)
      out << TextToken.new(text: text)
    else
      out.last.text << text
    end
  end

  class LexerError < StandardError
    def initialize(message, line, line_nr, col_nr)
      @message = message
      @line = line
      @line_nr = line_nr
      @col_nr = col_nr
    end

    BOLD = "\e[1m"
    RED = "\e[31m"
    RESET = "\e[0m"

    def message
      line_excerpt_start = [@col_nr - 38, 0].max
      line_excerpt_end = @col_nr + 38
      line_excerpt = @line[line_excerpt_start..line_excerpt_end]

      if line_excerpt_start > 0
        line_excerpt[0] = '…'
      end

      if line_excerpt_end < @line.size
        line_excerpt[-1] = '…'
      end

      [
        "#{RED}#{BOLD}ERROR#{RESET} (line #{@line_nr}, col #{@col_nr}): #{RED}#{@message}#{RESET}",
        '',
        line_excerpt,
        RED + ' ' * (@col_nr - 1 - line_excerpt_start) + '^' + RESET,
        '',
      ].join("\n")
    end
  end

  def lex_inline(string, line_nr)
    stack = []
    state = :root
    tokens = []
    name = ''
    col_nr = 0

    string.chars.each_with_index do |char|
      col_nr += 1

      case state
      when :root
        case char
        when '%'
          state = :after_pct
        when '}'
          if stack.empty?
            message = 'Unexpected `}`. Try escaping it as `%}`.'
            raise LexerError.new(message, string, line_nr, col_nr)
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
          col_nr -= 1
          append_text(tokens, '%')
        when '}' # escaped
          state = :root
          col_nr -= 1
          append_text(tokens, '}')
        when '{'
          state = :root
          stack << [:elem, name]
          tokens << TagBeginToken.new(name: name)
          name = ''
        else
          raise "line #{line_nr + 1}, col #{col_nr + 1}: unexpected `#{char}` after %"
        end
      else
        raise "Unexpected state: #{state.inspect}"
      end
    end

    tokens
  end
end

#########################

begin
  tokens = Lexer.new(File.read(ARGV[0])).run
rescue Lexer::LexerError => e
  $stderr.puts e.message
  exit 1
end

tree = Parser.new(tokens).run
translator = MyHTMLTranslator.new(tree)
puts translator.run
