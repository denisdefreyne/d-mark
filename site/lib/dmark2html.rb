require 'd-mark'

class Doc2HTML < DMark::Translator
  def handle_string(string)
    out << html_escape(string)
  end

  def handle_element(element, path)
    case element.name
    when 'p', 'dl', 'dt', 'dd', 'ol', 'ul', 'li', 'code', 'kbd', 'blockquote'
      wrap(element.name) { handle_children(element, path) }
    when 'h'
      depth = path.count { |el| el.name == 'section' } + 1
      wrap("h#{depth}") { handle_children(element, path) }
    when 'section'
      wrap('section', id: id_for_section(element)) { handle_children(element, path) }
    when 'emph'
      wrap('em') { handle_children(element, path) }
    when 'firstterm', 'prompt', 'filename'
      wrap('span', class: element.name) { handle_children(element, path) }
    when 'note', 'todo'
      wrap('div', class: element.name) { handle_children(element, path) }
    when 'link'
      wrap('a', href: element.attributes['target']) { handle_children(element, path) }
    when 'listing'
      wrap('pre') { wrap('code') { handle_children(element, path) } }
    else
      raise "Unhandled element name: #{element.name}"
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
