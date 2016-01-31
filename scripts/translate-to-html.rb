require_relative '../lib/dmark'

class MyHTMLTranslator < DMark::Translator
  def handle(node)
    case node
    when DMark::Nodes::RootNode
      handle_children(node)
    when DMark::Nodes::TextNode
      out << node.text
    when DMark::Nodes::ElementNode
      out << "<#{translate_elem_name(node.name)}>"
      handle_children(node)
      out << "</#{translate_elem_name(node.name)}>"
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

# Lex
begin
  tokens = DMark::Lexer.new(File.read(ARGV[0])).run
rescue DMark::Lexer::LexerError => e
  $stderr.puts e.message_for_tty
  exit 1
end

# Parse
tree = DMark::Parser.new(tokens).run

# Translate
result = MyHTMLTranslator.new(tree).run
puts result
