D★Mark
======

**Status:** experimental — use at your own risk!

_D★Mark_ is a markup language for writing text.

It is aimed at being able to write semantically meaningful text without limiting itself to the semantics provided by HTML or Markdown.

## Usage

Handling a D★Mark file consists of three stages: lexing, parsing, and translating.

The lexing stage converts the data into a stream of tokens. Construct a lexer with the data as input, and call `#run` to get the tokens, catching any `DMark::Lexer::LexerError`:

    begin
      tokens = DMark::Lexer.new(File.read(ARGV[0])).run
    rescue DMark::Lexer::LexerError => e
      $stderr.puts e.message_for_tty
      exit 1
    end

The parsing stage converts the stream of tokens into a node tree. Construct a parser with the tokens as input, and call `#run` to get the tree.

    tree = DMark::Parser.new(tokens).run

The translating stage is not the responsibility of D★Mark. A translator is part of the domain of the source text, and D★Mark only deals with syntax rather than semantics. A translator will run over the tree and convert it into something else (usually another string). To do so, handle each node type (`RootNode`, `TextNode`, `ElementNode`). For example, the following translator will convert the tree into something that resembles XML:

    class MyXMLLikeTranslator < DMark::Translator
      def handle(node)
        case node
        when DMark::Nodes::RootNode
          handle_children(node)
        when DMark::Nodes::TextNode
          out << node.text
        when DMark::Nodes::ElementNode
          out << "<#{node.name}>"
          handle_children(node)
          out << "</#{node.name}>"
        end
      end
    end

    result = MyXMLLikeTranslator.new(tree).run
    puts result

## Samples

The `samples/` directory contains some sample D★Mark files. They can be converted to HTML by running the `scripts/translate-to-html.rb` Ruby script, passing in the name of the file. The resulting HTML will be printed to standard output. For example:

    ruby scripts/translate-to-html.rb samples/identifiers-and-patterns.dmark

## Format

_D★Mark_ knows two constructs:

* Block-level elements. For example:

        p. Patterns are used to find items and layouts based on their identifier. They come in three varieties.

* Inline elements. For example:

        p. Identifiers come in two types: the %emph{full} type, new in Nanoc 4, and the %emph{legacy} type, used in Nanoc 3.

Block-level elements can be nested. For example:

    ul.
      li. glob patterns
      li. regular expression patterns
      li. legacy patterns
