require "./spec_helper"

class BeSuccessExpectation
  def initialize(@pos : Int32, @captures)
  end

  def match(value)
    @target = value

    case value
    when DMark::ParseSuccess
      if @captures == :__irrelevant__
        value.pos == @pos
      else
        value.pos == @pos && value.captures == @captures
      end
    else
      false
    end
  end

  def failure_message
    if @captures == :__irrelevant__
      "expected: success, pos = #{@pos}\n" \
      "     got: #{@target.inspect}"
    else
      "expected: success, pos = #{@pos}, captures = #{@captures.inspect}\n" \
      "     got: #{@target.inspect}"
    end
  end

  def negative_failure_message
    # FIXME
    "expected: #{@target.inspect}\n not to be a success"
  end
end

class BeFailureExpectation
  def initialize(@pos : Int32, @message : String | Nil)
  end

  def match(value)
    @target = value

    case value
    when DMark::ParseFailure
      value.pos == @pos && value.message == @message
    else
      false
    end
  end

  def failure_message
    "expected: #{@target.inspect}\nto be a failure with end pos #{@pos} and message #{@message.inspect}"
  end

  def negative_failure_message
    "expected: #{@target.inspect}\n not to be a failure"
  end
end

def be_success(pos)
  BeSuccessExpectation.new(pos, :__irrelevant__)
end

def be_success(pos, captures)
  BeSuccessExpectation.new(pos, captures)
end

def be_failure(pos, message)
  BeFailureExpectation.new(pos, message)
end

describe "DMark::P.char" do
  it "parses chars" do
    DMark::P.char('a').parse("a", 0).should be_success(1)
  end

  it "does not parse non-chars" do
    DMark::P.char('a').parse("b", 0).should be_failure(0, nil)
    DMark::P.char('a').parse("", 0).should be_failure(0, nil)
  end
end

describe "DMark::P.capture" do
  parser = DMark::P.capture(:donkey, DMark::P.char('a'))

  it "captures" do
    parser.parse("a", 0).should be_success(1, { donkey: "a" })
  end
end

describe "DMark::P.or" do
  parser = DMark::P.or(DMark::P.char('a'), DMark::P.char('b'))

  it "parses" do
    parser.parse("a", 0).should be_success(1)
    parser.parse("b", 0).should be_success(1)
  end

  it "half-parses" do
    parser.parse("ax", 0).should be_success(1)
    parser.parse("bx", 0).should be_success(1)
  end

  it "does not parse" do
    parser.parse("x", 0).should be_failure(0, nil)
  end
end

describe "DMark::P.and" do
  parser = DMark::P.and(DMark::P.char('a'), DMark::P.char('b'))

  it "parses" do
    parser.parse("ab", 0).should be_success(2)
  end

  it "does not parse" do
    parser.parse("", 0).should be_failure(0, nil)
    parser.parse("a", 0).should be_failure(1, nil)
    parser.parse("b", 0).should be_failure(0, nil)
    parser.parse("aa", 0).should be_failure(1, nil)
    parser.parse("aab", 0).should be_failure(1, nil)
  end
end

describe "DMark::P.repeat_zero_or_more" do
  parser = DMark::P.repeat_zero_or_more(DMark::P.char('a'))

  it "parses repeats" do
    parser.parse("", 0).should be_success(0)
    parser.parse("a", 0).should be_success(1)
    parser.parse("aa", 0).should be_success(2)
  end

  it "half-parses until repeat end" do
    parser.parse("b", 0).should be_success(0)
    parser.parse("ab", 0).should be_success(1)
    parser.parse("aab", 0).should be_success(2)
  end
end

describe "DMark::P.repeat_one_or_more" do
  parser = DMark::P.repeat_one_or_more(DMark::P.char('a'))

  it "parses repeats" do
    parser.parse("a", 0).should be_success(1)
    parser.parse("aa", 0).should be_success(2)
  end

  it "half-parses until repeat end" do
    parser.parse("ab", 0).should be_success(1)
    parser.parse("aab", 0).should be_success(2)
  end

  it "does not parse non-repeats" do
    parser.parse("", 0).should be_failure(0, nil)
    parser.parse("b", 0).should be_failure(0, nil)
  end
end

describe "DMark::P.sequence" do
  parser = DMark::P.sequence([DMark::P.char('a'),DMark::P.char('b')])

  it "parses" do
    parser.parse("ab", 0).should be_success(2)
  end

  it "half-parses" do
    parser.parse("abc", 0).should be_success(2)
  end

  it "does not parse" do
    parser.parse("", 0).should be_failure(0, nil)
    parser.parse("a", 0).should be_failure(1, nil)
    parser.parse("ax", 0).should be_failure(1, nil)
    parser.parse("b", 0).should be_failure(0, nil)
    parser.parse("ba", 0).should be_failure(0, nil)
  end
end

describe "DMark::P.sequence + captures" do
  parser =
    DMark::P.sequence(
      [
        DMark::P.capture(:foo, DMark::P.char('a')),
        DMark::P.capture(:bar, DMark::P.char('b')),
      ]
    )

  it "parses" do
    parser.parse("ab", 0).should be_success(2, { foo: "a", bar: "b" })
  end
end

describe "DMark::Px.identifier" do
  it "parses identifiers" do
    DMark::Px.identifier.parse("a", 0).should be_success(1)
    DMark::Px.identifier.parse("aa", 0).should be_success(2)
    DMark::Px.identifier.parse("abcdefghijklmnopqrstuvwxyz", 0).should be_success(26)
    DMark::Px.identifier.parse("a1", 0).should be_success(2)
  end

  it "half-parses until identifier ends" do
    DMark::Px.identifier.parse("a?", 0).should be_success(1)
    DMark::Px.identifier.parse("a.", 0).should be_success(1)
    DMark::Px.identifier.parse("donkey ", 0).should be_success(6)
  end

  it "does not parse non-identifiers" do
    DMark::Px.identifier.parse("", 0).should be_failure(0, nil)
    DMark::Px.identifier.parse("?", 0).should be_failure(0, nil)
    DMark::Px.identifier.parse("1", 0).should be_failure(0, nil)
    DMark::Px.identifier.parse("1a", 0).should be_failure(0, nil)
  end
end

# describe "DMark::Px.block_start" do
# end

describe "DMark::Px.inline_content" do
  parser = DMark::Px.inline_content

  it "parses inlines - basic content" do
    parser.parse("", 0).should be_success(0)
    parser.parse("a", 0).should be_success(1)
    parser.parse("{", 0).should be_success(1)
    parser.parse("[", 0).should be_success(1)
    parser.parse("a{", 0).should be_success(2)
    parser.parse("AbCdE", 0).should be_success(5)
    parser.parse("AbCdE#?! {", 0).should be_success(10)

    parser.parse("%donkey{}", 0).should be_success(9)
    parser.parse("foo %donkey{}", 0).should be_success(13)
    parser.parse("%donkey{} bar", 0).should be_success(13)
    parser.parse("%donkey{abc}", 0).should be_success(12)
    parser.parse("foo %donkey{abc}", 0).should be_success(16)
    parser.parse("%donkey{abc} bar", 0).should be_success(16)

    parser.parse("%donkey{%giraffe{moo}} bar", 0).should be_success(26)

    parser.parse("foo %% bar", 0).should be_success(10)
    parser.parse("foo %} bar", 0).should be_success(10)
  end

  it "half-parses until inline ends" do
    parser.parse("abc%", 0).should be_success(3)
    parser.parse("abc}", 0).should be_success(3)
    parser.parse("abc\n", 0).should be_success(3)
  end

  it "does not parse non-inlines" do
    parser.parse("%", 0).should be_success(0)
    parser.parse("}", 0).should be_success(0)
    parser.parse("\n", 0).should be_success(0)
  end
end

describe "DMark::Px.inline_element" do
  parser = DMark::Px.inline_element

  it "parses inline elements" do
    parser.parse("%a{}", 0).should be_success(4)
    parser.parse("%aaa{}", 0).should be_success(6)

    parser.parse("%aaa{x}", 0).should be_success(7)
    parser.parse("%aaa{abc}", 0).should be_success(9)

    parser.parse("%aaa{%giraffe{}}", 0).should be_success(16)
    parser.parse("%aaa{%giraffe{123}}", 0).should be_success(19)
  end

  it "does not parse non-inline elements" do
    parser.parse("%", 0).should be_failure(1, "expected identifier after %")
    parser.parse("%a", 0).should be_failure(2, "expected { after identifier")
    parser.parse("%a{", 0).should be_failure(3, nil)
    parser.parse("%a}", 0).should be_failure(2, "expected { after identifier")
  end
end

describe "DMark::Px.lone_block" do
  parser = DMark::Px.lone_block

  it "parses" do
    parser.parse("p.", 0).should be_success(2, { name: "p" })
    parser.parse("p.\n", 0).should be_success(2, { name: "p" })
    parser.parse("p. ", 0).should be_success(3, { name: "p" })
    parser.parse("p. \n", 0).should be_success(3, { name: "p" })
    parser.parse("p. hi", 0).should be_success(5, { name: "p" })
    parser.parse("p. hi\n", 0).should be_success(5, { name: "p" })
    parser.parse("p. hello %emph{world}", 0).should be_success(21, { name: "p" })
    parser.parse("p. hello %emph{world}\n", 0).should be_success(21, { name: "p" })
  end

  it "refuses to parse" do
    parser.parse("", 0).should be_failure(0, "expected identifier at beginning of block")
    parser.parse(".", 0).should be_failure(0, "expected identifier at beginning of block")
    parser.parse("p", 0).should be_failure(1, "expected period after identifier")
    parser.parse("p/", 0).should be_failure(1, "expected period after identifier")
  end
end
