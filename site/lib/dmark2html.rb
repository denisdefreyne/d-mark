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
  def handle_string(string, context)
    [context[:raw] ? string : html_escape(string)]
  end

  def handle_element(element, context)
    case element.name
    when 'p', 'dl', 'dt', 'dd', 'ol', 'ul', 'li', 'code', 'kbd', 'blockquote', 'b'
      wrap(element.name) { handle_children(element, context) }
    when 'byline'
      wrap('div', class: 'byline') { handle_children(element, context) }
    when 'h'
      depth = context.fetch(:depth, 1)
      wrap("h#{depth}") do
        before =
          if depth == 1
            []
          else
            wrap('a', href: '#' + id_for_header(element), class: 'permalink') { ['#'] }
          end

        [before, handle_children(element, context)]
      end
    when 'section'
      sub_depth = context.fetch(:depth, 1) + 1
      wrap('section', id: id_for_section(element)) do
        handle_children(element, context.merge(depth: sub_depth))
      end
    when 'em'
      wrap('em') { handle_children(element, context) }
    when 'firstterm', 'prompt', 'filename'
      wrap('span', class: element.name) { handle_children(element, context) }
    when 'note', 'todo'
      wrap('div', class: element.name) { handle_children(element, context) }
    when 'link'
      attrs = { href: element.attributes['target'] }
      attrs['rel'] = element.attributes['rel'] if element.attributes['rel']
      wrap('a', attrs) { handle_children(element, context) }
    when 'listing'
      wrap('pre') do
        wrap('code') do
          if element.attributes['lang']
            addition = translate(element.children, context.merge(raw: true))
            formatter = ::Rouge::Formatters::HTML.new(wrap: false)
            lexer = ::Rouge::Lexer.find(element.attributes['lang'])
            raise "Can’t find lexer for #{element.attributes['lang']}" if lexer.nil?

            formatter.format(lexer.lex(addition))
          else
            translate(element.children, context)
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

  def id_for_section(element)
    id_for_header(element.children.find { |c| c.name == 'h' })
  end

  def id_for_header(element)
    element.children.join('').downcase.gsub(/[^a-zA-Z-]/, '-')
  end
end

Class.new(Nanoc::Filter) do
  identifier :dmark2html

  def run(content, _params = {})
    tree = DMark::Parser.new(content).parse
    Doc2HTML.translate(tree)
  end
end
