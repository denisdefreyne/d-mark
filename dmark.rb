require_relative 'lib/dmark'

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
      when DMark::Tokens::TextToken
        node_stack.last.children << TextNode.new(text: token.text)
      when DMark::Tokens::TagBeginToken
        new_node = ElementNode.new(name: token.name)
        node_stack.last.children << new_node
        node_stack.push(new_node)
      when DMark::Tokens::TagEndToken
        node_stack.pop
      end
    end

    @root_node
  end
end

#########################

# Lex
begin
  tokens = DMark::Lexer.new(File.read(ARGV[0])).run
rescue DMark::Lexer::LexerError => e
  $stderr.puts e.message
  exit 1
end

# Parse
tree = Parser.new(tokens).run

# Translate
result = MyHTMLTranslator.new(tree).run
puts result
