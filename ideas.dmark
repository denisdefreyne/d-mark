h1. Ideas

ul.
  li.
    p. Use %code{%%ref{/doc/tutorial.*}} to reference other pages. On web, this will become links (e.g. “see the Tutorial chapter”), and in PDF, these will be cross-references.

  li.
    p. We can now have proper admonitions (tips, notes and cautions) and the ugly hacks we currently have can be removed.

  li.
    p. Support line breaks in the same block-level element. A potential problem arises when the next line also starts with a valid element and a period, though.

  li.
    p. Support comments. Maybe %% at the beginning of a line, or at the current indentation level?

  li.
    p. Support validation. Which elements can contain which other elements? Which elements can live at the root?

  li.
    p. Build an element tree first, and let the converters work on that. A basic “simple converter” for translating elements one-to-one could be provided by default.

  li.
    p. Pushing { onto the stack does not make sense. Any } that does not correspond with the end of an inline element needs to be escaped. If not, there’s no way to have an inline element with only an opening accolade.

  li.
    p. A lone %% should probably be okay. Maybe everything that doesn’t fully look like an inline element (e.g. %%code) could be acceptable.

  li.
    p. We need attribute support. The example “identifiers and patterns” document already contains attributes, but they’re ignored at the moment. That file uses %code{listing[lang=ruby]} and %code{dl[legacy]} as examples.
