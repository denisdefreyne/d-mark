D★Mark
======

**Status:** experimental — use at your own risk!

_D★Mark_ is a markup language for writing text.

It is aimed at being able to write semantically meaningful text without limiting itself to the semantics provided by HTML or Markdown.

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
