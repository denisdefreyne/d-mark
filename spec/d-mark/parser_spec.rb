def parse(s)
  DMark::Parser.new(s).parse
end

def element(name, attributes, children)
  DMark::Parser::ElementNode.new(name, attributes, children)
end

def empty_children
  []
end

def empty_attrs
  {}
end

def children(xs)
  xs
end

describe "DMark::Parser#parser" do
  text = "p. hello %% %} hi %element{foo %emph{not} omg}"
  parser = DMark::Parser.new(text)

  it "parses" do
    parse("").should eq []
    parse("p.").should eq [element("p", empty_attrs, empty_children)]
    parse("p. hi").should eq [element("p", empty_attrs, ["hi"])]
    parse("p. hi %%").should eq [element("p", empty_attrs, ["hi ", "%"])]
    parse("p. hi %}").should eq [element("p", empty_attrs, ["hi ", "}"])]
  end

  it "parses escaped % in block" do
    parse("p. %%").should eq [
      element("p", empty_attrs, ["%"]),
    ]
  end

  it "parses escaped } in block" do
    parse("p. %}").should eq [
      element("p", empty_attrs, ["}"]),
    ]
  end

  it "parses escaped % in inline block" do
    parse("p. %foo{%%}").should eq [
      element("p", empty_attrs, [
        element("foo", empty_attrs, ["%"]),
      ])
    ]
  end

  it "parses escaped } in inline block" do
    parse("p. %foo{%}}").should eq [
      element("p", empty_attrs, [
        element("foo", empty_attrs, ["}"]),
      ])
    ]
  end

  it "parses block with text and element content" do
    parse("p. hi %em{ho}").should eq [
      element("p", empty_attrs, [
        "hi ",
        element("em", empty_attrs, ["ho"]),
      ]),
    ]
  end

  it "parses block with text and element content, followed by newline" do
    parse("p. hi %em{ho}\n").should eq [
      element("p", empty_attrs, [
        "hi ",
        element("em", empty_attrs, ["ho"]),
      ]),
    ]
  end

  it "parses children" do
    parse("p. hi %em{ho}\n  p. child p").should eq [
      element("p", empty_attrs, [
        "hi ",
        element("em", empty_attrs, ["ho"]),
        element("p", empty_attrs, ["child p"]),
      ]),
    ]
  end

  it "parses children multiple levels deep" do
    parse("p. hi %em{ho}\n  p. child p\n    p. subchild p").should eq [
      element("p", empty_attrs, [
        "hi ",
        element("em", empty_attrs, ["ho"]),
        element("p", empty_attrs, [
          "child p",
          element("p", empty_attrs, [
            "subchild p",
          ]),
        ]),
      ]),
    ]
  end

  it "ignores blanks" do
    parse("p. foo\n \n  p. bar\n  \n\n    p. qux").should eq [
      element("p", empty_attrs, [
        "foo",
        element("p", empty_attrs, [
          "bar",
          element("p", empty_attrs, [
            "qux",
          ]),
        ]),
      ]),
    ]
  end

  it "reads multiple consecutive blocks" do
    parse("p. foo\np. bar").should eq [
      element("p", empty_attrs, ["foo"]),
      element("p", empty_attrs, ["bar"]),
    ]
  end

  it "includes raw content" do
    parse("p. foo\n  donkey").should eq [
      element("p", empty_attrs, ["foo", "\n", "donkey"]),
    ]
  end

  it "includes raw content including initial indentation" do
    parse("p. foo\n    donkey").should eq [
      element("p", empty_attrs, ["foo", "\n", "  donkey"]),
    ]
  end

  it "includes raw content from multiple lines" do
    parse("p. foo\n    donkey\n  giraffe\n    zebra\n").should eq [
      element("p", empty_attrs, ["foo", "\n", "  donkey", "\n", "giraffe", "\n", "  zebra"]),
    ]
  end

  it "includes empty lines in raw content" do
    parse("p. foo\n\n  donkey\n\n    giraffe\n").should eq [
      element("p", empty_attrs, ["foo", "\n", "\n", "donkey", "\n", "\n", "  giraffe"]),
    ]
  end

  it "does not include line break after empty block element and before data lines" do
    parse("p.\n  donkey\n").should eq [
      element("p", empty_attrs, ["donkey"]),
    ]
  end

  it "parses inline element in data lines" do
    parse("p.\n  %emph{donkey}\n").should eq [
      element("p", empty_attrs, [
        element("emph", empty_attrs, ["donkey"]),
      ]),
    ]
  end

  it "parses empty attributes" do
    parse("p[]. hi").should eq [
      element("p", empty_attrs, ["hi"]),
    ]
  end

  it "parses single attribute" do
    parse("p[foo=bar]. hi").should eq [
      element("p", { "foo" => "bar" }, ["hi"]),
    ]
  end

  it "parses single value-less attribute" do
    parse("p[foo]. hi").should eq [
      element("p", { "foo" => "foo" }, ["hi"]),
    ]
  end

  it "parses multiple attributes" do
    parse("p[foo=bar,qux=donkey]. hi").should eq [
      element("p", { "foo" => "bar", "qux" => "donkey" }, ["hi"]),
    ]
  end

  it "parses multiple value-less attributes" do
    parse("p[foo,qux]. hi").should eq [
      element("p", { "foo" => "foo", "qux" => "qux" }, ["hi"]),
    ]
  end

  it "parses escaped attributes" do
    parse("p[foo=%],bar=%%,donkey=%,]. hi").should eq [
      element("p", { "foo" => "]", "bar" => "%", "donkey" => "," }, ["hi"]),
    ]
  end

  it "parses attributes in empty block" do
    parse("p[foo=bar].\n  hi").should eq [
      element("p", { "foo" => "bar" }, ["hi"]),
    ]
  end

  it "parses block start on next line properly" do
    parse("p.\n  this is not a child block.").should eq [
      element("p", empty_attrs, ["this is not a child block."]),
    ]
  end

  it "parses block start on next line with spacey" do
    parse("p.\n  foo.bar").should eq [
      element("p", empty_attrs, ["foo.bar"]),
    ]
  end

  it "does not parse" do
    expect { parse("p") }.to raise_error(DMark::Parser::ParserError)
    expect { parse("0") }.to raise_error(DMark::Parser::ParserError)
    expect { parse("p0") }.to raise_error(DMark::Parser::ParserError)
    expect { parse("0.") }.to raise_error(DMark::Parser::ParserError)
    expect { parse("p. %") }.to raise_error(DMark::Parser::ParserError)
    expect { parse("p. }") }.to raise_error(DMark::Parser::ParserError)
  end
end
