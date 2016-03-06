require 'd-mark'

class Doc2HTML < DMark::Translator
  def handle(node, depths = {})
    case node
    when String
      out << html_escape(node)
    when DMark::ElementNode
      case node.name
      when 'p', 'dl', 'dt', 'dd', 'ol', 'ul', 'li', 'code', 'kbd', 'blockquote'
        wrap(node.name) { handle_children(node, depths) }
      when 'h'
        depth = depths.fetch('section', 0) + 1
        wrap("h#{depth}") { handle_children(node, depths) }
      when 'section'
        wrap('section', id: id_for_section(node)) { handle_children(node, depths) }
      when 'emph'
        wrap('em') { handle_children(node, depths) }
      when 'firstterm', 'prompt', 'filename'
        wrap('span', class: node.name) { handle_children(node, depths) }
      when 'note', 'todo'
        wrap('div', class: node.name) { handle_children(node, depths) }
      when 'link'
        wrap('a', href: node.attributes['target']) { handle_children(node, depths) }
      when 'listing'
        wrap('pre') { wrap('code') { handle_children(node, depths) } }
      else
        raise "Unhandled node name: #{node.name}"
      end
    end
  end

  def wrap(name, params = {})
    params_string = params.map { |k, v| " #{k}=\"#{html_escape(v)}\"" }.join('')
    out << "<#{name}#{params_string}>"
    yield
    out << "</#{name}>"
  end

  def html_escape(s)
    s.gsub('&', '&amp;').gsub('<', '&lt;')
  end

  def handle_children(node, depths)
    new_depths = depths.merge({ node.name => depths.fetch(node.name, 0) + 1 })
    node.children.each { |child| handle(child, new_depths) }
  end

  def id_for_section(node)
    header = node.children.find { |c| c.name == 'h' }
    text = header.children.join('')
    text.downcase.gsub(/[^a-zA-Z-]/, '-')
  end
end

Class.new(Nanoc::Filter) do
  identifier :dmark2html

  def run(content, params = {})
    tree = DMark::Parser.new(content).parse
    Doc2HTML.new(tree).run
  end
end
