require 'd-mark'

class MyHTMLTranslator < DMark::Translator
  def handle(node)
    case node
    when String
      out << node
    when DMark::ElementNode
      out << "<#{node.name}>"
      handle_children(node)
      out << "</#{node.name}>"
    end
  end
end

content = File.read('samples/trivial.dmark')
parser = DMark::Parser.new(content)
tree = parser.parse

puts MyHTMLTranslator.new(tree).run
