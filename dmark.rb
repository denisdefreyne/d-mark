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
    when DMark::Nodes::RootNode
      node.children.each { |child| handle(child, io) }
    when DMark::Nodes::TextNode
      io << node.text
    when DMark::Nodes::ElementNode
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

# Lex
begin
  tokens = DMark::Lexer.new(File.read(ARGV[0])).run
rescue DMark::Lexer::LexerError => e
  $stderr.puts e.message
  exit 1
end

# Parse
tree = DMark::Parser.new(tokens).run

# Translate
result = MyHTMLTranslator.new(tree).run
puts result
