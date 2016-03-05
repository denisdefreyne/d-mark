require 'd-mark'

HEADER = <<EOS
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>D★Mark</title>
    <link href='https://fonts.googleapis.com/css?family=Montserrat:700' rel='stylesheet' type='text/css'>
    <link href='https://fonts.googleapis.com/css?family=Merriweather:400,400italic,700' rel='stylesheet' type='text/css'>
    <link href='https://fonts.googleapis.com/css?family=Cousine:400,700,400italic,700italic' rel='stylesheet' type='text/css'>
    <style>
      * {
        margin: 0;
        padding: 0;
      }

      html {
        font-size: 15px;
        line-height: 1.5rem;
        padding: 4rem;
        border-left: 1rem solid #ee5070;
      }

      body {
        max-width: 720px;
        font-family: Merriweather, serif;
        color: #444;
        background-color: #f8fcff;
      }

      h1, h2, h3 {
        font-family: Montserrat, sans-serif;
        line-height: 1em;
        margin: 1.5em 0 1em 0;
        color: #ee5070;
      }

      h1 {
        font-size: 48px;
        margin-top: 0;
      }

      h2 {
        font-size: 36px;
      }

      h3 {
        font-size: 24px;
      }

      em, .firstterm {
        font-style: italic;
      }

      a:link, a:visited {
        color: rgb(77, 103, 242);
      }

      a:hover {
        color: #ee5070;
      }

      a:active {
        color: #000;
      }

      dl, p, pre, ul, ol, .note, .todo {
        margin: 0 0 1.5rem 0;
      }

      dt {
        font-weight: bold;
        color: #000;
        margin: 2rem 0 1rem 0;
      }

      dd {
        margin: 0 0 1em 0;
        padding: 0 0 0 2em;
      }

      ul, ol {
        margin-left: 2rem;
      }

      pre {
        padding: 1em;
        background: rgba(77, 103, 242, 0.1);
        color: #000;
        white-space: pre-wrap;
      }

      code, kbd, samp, var {
        font-size: 14px;
        font-family: Cousine, monospace;
      }

      .dmark-punctuation {
        color: #999;
      }

      .dmark-elem {
        font-weight: bold;
      }

      .prompt {
        color: #999;
      }

      kbd {
        font-weight: bold;
      }

      .filename {
        font-style: italic;
      }

      .note {
        padding: 1em;
        border: 1px solid #000;
      }

      .note:before {
        content: "NOTE: ";
        font-weight: bold;
        font-family: Montserrat, sans-serif;
      }

      .todo {
        padding: 1em;
        color: #d00;
        background: rgba(255, 0, 0, 0.05);
        border: 1px solid #f00;
      }

      .todo:before {
        content: "TODO: ";
        font-weight: bold;
        font-family: Montserrat, sans-serif;
      }
    </style>
  </head>
  <body>
EOS

FOOTER = <<EOS
  </body>
</html>
EOS

class Doc2HTML < DMark::Translator
  def handle(node, depths = {})
    case node
    when String
      out << html_escape(node)
    when DMark::ElementNode
      case node.name
      when 'p', 'dl', 'dt', 'dd', 'ol', 'ul', 'li', 'code', 'kbd'
        wrap(node.name) { handle_children(node, depths) }
      when 'h'
        depth = depths.fetch('section', 0) + 1
        wrap("h#{depth}") { handle_children(node, depths) }
      when 'section'
        handle_children(node, depths)
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
end

if ARGV.size != 2
  $stderr.puts "usage: #{$0} [input-filename] [output-filename]"
  exit 1
end

content = File.read(ARGV[0])
parser = DMark::Parser.new(content)
tree = parser.parse

File.write(ARGV[1], HEADER + Doc2HTML.new(tree).run + FOOTER)
