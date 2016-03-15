require 'd-mark'
require 'rouge'

class DMarkRougLexer < Rouge::RegexLexer
  tag 'd-mark'
  filenames '*.dmark'

  state :root do
    rule /^(  )*#[a-z][a-z0-9]*/, Name::Tag
    rule /%[a-z][a-z0-9]*/, Name::Tag
  end
end

class Doc2HTML < DMark::Translator
  def handle_string(string)
    [html_escape(string)]
  end

  def handle_element(element, path)
    case element.name
    when 'p', 'dl', 'dt', 'dd', 'ol', 'ul', 'li', 'code', 'kbd', 'blockquote'
      wrap(element.name) { handle_children(element, path) }
    when 'h'
      depth = path.count { |el| el.name == 'section' } + 1
      wrap("h#{depth}") do
        before =
          if depth == 1
            []
          else
            wrap('a', href: '#' + id_for_header(element), class: 'permalink') { ['#'] }
          end

        [before, handle_children(element, path)]
      end
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
      wrap('pre') do
        wrap('code') do
          addition = [handle_children(element, path)].flatten.join

          if element.attributes['lang']
            formatter = ::Rouge::Formatters::HTML.new(wrap: false)
            lexer = ::Rouge::Lexer.find(element.attributes['lang'])
            raise "Can’t find lexer for #{element.attributes['lang']}" if lexer.nil?

            formatter.format(lexer.lex(html_unescape(addition)))
          else
            addition
          end
        end
      end
    else
      raise "Unhandled element name: #{element.name}"
    end
  end

  def wrap(name, params = {})
    params_string = params.map { |k, v| " #{k}=\"#{html_escape(v)}\"" }.join('')
    ["<#{name}#{params_string}>", yield, "</#{name}>"]
  end

  def html_escape(s)
    s.gsub('&', '&amp;').gsub('<', '&lt;')
  end

  # FIXME: ugly that we need this
  def html_unescape(s)
    s.gsub('&lt;', '<').gsub('&amp;', '&')
  end

  def id_for_section(element)
    id_for_header(element.children.find { |c| c.name == 'h' })
  end

  def id_for_header(element)
    element.children.join('').downcase.gsub(/[^a-zA-Z-]/, '-')
  end
end

Class.new(Nanoc::Filter) do
  identifier :dmark2html

  def run(content, params = {})
    tree = DMark::Parser.new(content).parse
    Doc2HTML.new(tree).run
  end
end
