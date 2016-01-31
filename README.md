D★Mark
======

**Status:** experimental — use at your own risk!

_D★Mark_ is a markup language for writing text.

It is aimed at being able to write semantically meaningful text without limiting itself to the semantics provided by HTML or Markdown.

## Usage

Section pending.

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
