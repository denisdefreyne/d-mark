require "./spec_helper"

def parse(s)
  DMark::Parser.new(s).parse
end

def element(name, attributes, children)
  DMark::Parser::ElementNode.new(name, attributes, children)
end

def empty_children
  [] of DMark::Parser::ElementNode | String
end

def empty_attrs
  {} of String => String
end

def children(xs)
  res = [] of DMark::Parser::ElementNode | String
  xs.each { |x| res << x }
  res
end

describe "DMark::Parser#parser" do
  text = "p. hello %% %} hi %element{foo %emph{not} omg}"
  parser = DMark::Parser.new(text)

  it "parses" do
    parse("").should eq [] of DMark::Parser::ElementNode
    parse("p.").should eq [element("p", empty_attrs, empty_children)]
    parse("p. hi").should eq [element("p", empty_attrs, children ["hi"])]
    parse("p. hi %%").should eq [element("p", empty_attrs, children ["hi ", "%"])]
    parse("p. hi %}").should eq [element("p", empty_attrs, children ["hi ", "}"])]
  end

  it "parses block with text and element content" do
    parse("p. hi %em{ho}").should eq [
      element("p", empty_attrs, children [
        "hi ",
        element("em", empty_attrs, children ["ho"]),
      ]),
    ]
  end

  it "parses block with text and element content, followed by newline" do
    parse("p. hi %em{ho}\n").should eq [
      element("p", empty_attrs, children [
        "hi ",
        element("em", empty_attrs, children ["ho"]),
      ]),
    ]
  end

  it "parses children" do
    parse("p. hi %em{ho}\n  p. child p").should eq [
      element("p", empty_attrs, children [
        "hi ",
        element("em", empty_attrs, children ["ho"]),
        element("p", empty_attrs, children ["child p"]),
      ]),
    ]
  end

  it "parses children multiple levels deep" do
    parse("p. hi %em{ho}\n  p. child p\n    p. subchild p").should eq [
      element("p", empty_attrs, children [
        "hi ",
        element("em", empty_attrs, children ["ho"]),
        element("p", empty_attrs, children [
          "child p",
          element("p", empty_attrs, children [
            "subchild p",
          ]),
        ]),
      ]),
    ]
  end

  it "ignores blanks" do
    parse("p. foo\n \n  p. bar\n  \n\n    p. qux").should eq [
      element("p", empty_attrs, children [
        "foo",
        element("p", empty_attrs, children [
          "bar",
          element("p", empty_attrs, children [
            "qux",
          ]),
        ]),
      ]),
    ]
  end

  it "reads multiple consecutive blocks" do
    parse("p. foo\np. bar").should eq [
      element("p", empty_attrs, children ["foo"]),
      element("p", empty_attrs, children ["bar"]),
    ]
  end

  it "includes raw content" do
    parse("p. foo\n  donkey").should eq [
      element("p", empty_attrs, children ["foo", "\n", "donkey"]),
    ]
  end

  it "includes raw content including initial indentation" do
    parse("p. foo\n    donkey").should eq [
      element("p", empty_attrs, children ["foo", "\n", "  donkey"]),
    ]
  end

  it "includes raw content from multiple lines" do
    parse("p. foo\n    donkey\n  giraffe\n    zebra\n").should eq [
      element("p", empty_attrs, children ["foo", "\n", "  donkey", "\n", "giraffe", "\n", "  zebra"]),
    ]
  end

  it "includes empty lines in raw content" do
    parse("p. foo\n\n  donkey\n\n    giraffe\n").should eq [
      element("p", empty_attrs, children ["foo", "\n", "\n", "donkey", "\n", "\n", "  giraffe"]),
    ]
  end

  it "does not include line break after empty block element and before data lines" do
    parse("p.\n  donkey\n").should eq [
      element("p", empty_attrs, children ["donkey"]),
    ]
  end

  it "parses empty attributes" do
    parse("p[]. hi").should eq [
      element("p", empty_attrs, children ["hi"]),
    ]
  end

  it "parses single attribute" do
    parse("p[foo=bar]. hi").should eq [
      element("p", { "foo" => "bar" }, children ["hi"]),
    ]
  end

  it "parses single value-less attribute" do
    parse("p[foo]. hi").should eq [
      element("p", { "foo" => "foo" }, children ["hi"]),
    ]
  end

  it "parses multiple attributes" do
    parse("p[foo=bar,qux=donkey]. hi").should eq [
      element("p", { "foo" => "bar", "qux" => "donkey" }, children ["hi"]),
    ]
  end

  it "parses multiple value-less attributes" do
    parse("p[foo,qux]. hi").should eq [
      element("p", { "foo" => "foo", "qux" => "qux" }, children ["hi"]),
    ]
  end

  it "parses escaped attributes" do
    parse("p[foo=%],bar=%%,donkey=%,]. hi").should eq [
      element("p", { "foo" => "]", "bar" => "%", "donkey" => "," }, children ["hi"]),
    ]
  end

  it "does not parse" do
    expect_raises(DMark::Parser::ParserError) { parse("p") }
    expect_raises(DMark::Parser::ParserError) { parse("0") }
    expect_raises(DMark::Parser::ParserError) { parse("p0") }
    expect_raises(DMark::Parser::ParserError) { parse("0.") }
    expect_raises(DMark::Parser::ParserError) { parse("p. %") }
    expect_raises(DMark::Parser::ParserError) { parse("p. }") }
  end
end
