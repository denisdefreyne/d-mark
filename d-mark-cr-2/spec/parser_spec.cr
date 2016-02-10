require "./spec_helper"

def parse(s)
  DMark::Parser.new(s).parse
end

def element(name, children)
  DMark::Parser::ElementNode.new(name, children)
end

def empty_children
  [] of DMark::Parser::ElementNode | String
end

describe "DMark::Parser#parser" do
  text = "p. hello %% %} hi %element{foo %emph{not} omg}"
  parser = DMark::Parser.new(text)

  it "parses" do
    parse("").should eq [] of DMark::Parser::ElementNode
    parse("p.").should eq [element("p", empty_children)]
    parse("p. hi").should eq [element("p", ["hi"])]
    parse("p. hi %%").should eq [element("p", ["hi ", "%"])]
    parse("p. hi %}").should eq [element("p", ["hi ", "}"])]
    parse("p. hi %em{ho}").should eq [element("p", ["hi ", element("em", ["ho"])])]
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
