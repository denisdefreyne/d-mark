require "./d-mark/*"

module DMark
  struct ParseSuccess
    getter :pos
    getter :data

    def initialize(@pos : Int32, @data)
    end
  end

  struct ParseFailure
    getter :pos
    getter :message

    def initialize(@pos : Int32, @message)
    end
  end

  module Parsers
    struct Char
      def initialize(@char)
      end

      def parse(input : String, pos : Int32)
        if pos >= input.size
          ParseFailure.new(pos, nil)
        elsif input[pos] == @char
          ParseSuccess.new(pos+1, nil)
        else
          ParseFailure.new(pos, nil)
        end
      end
    end

    struct EOF
      def initialize
      end

      def parse(input : String, pos : Int32)
        if pos == input.size
          ParseSuccess.new(pos, nil)
        else
          ParseFailure.new(pos, nil)
        end
      end
    end

    struct Sequence
      def initialize(@ps)
      end

      def parse(input : String, pos : Int32)
        prev_pos = pos

        @ps.each do |p1|
          res = p1.parse(input, prev_pos)
          case res
          when ParseSuccess
            prev_pos = res.pos
          when ParseFailure
            return ParseFailure.new(pos, res.message)
          else
            raise "???"
          end
        end

        ParseSuccess.new(prev_pos, nil)
      end
    end

    struct Capture
      def initialize(@name, @p)
      end

      def parse(input : String, pos : Int32)
        res = @p.parse(input, pos)
        case res
        when ParseSuccess
          capture = input[pos...res.pos]
          data = res.data || {} of Symbol => String | Array(String)
          ParseSuccess.new(res.pos, data.merge({ @name => capture }))
        when ParseFailure
          res
        else
          raise "???"
        end
      end
    end

    class Or
      def initialize(@p1, @p2)
      end

      def parse(input : String, pos : Int32)
        res_a = @p1.parse(input, pos)
        case res_a
        when ParseSuccess
          res_a
        when ParseFailure
          @p2.parse(input, pos)
        else
          raise "???"
        end
      end
    end

    class Peek
      def initialize(@p)
      end

      def parse(input : String, pos : Int32)
        res = @p.parse(input, pos)
        case res
        when ParseSuccess
          ParseSuccess.new(pos, nil)
        when ParseFailure
          res
        else
          raise "???"
        end
      end
    end

    struct Range
      def initialize(@range)
      end

      def parse(input : String, pos : Int32)
        if pos >= input.size
          ParseFailure.new(pos, nil)
        elsif @range.includes?(input[pos])
          ParseSuccess.new(pos+1, nil)
        else
          ParseFailure.new(pos, nil)
        end
      end
    end

    struct AllBut
      def initialize(@disallowed_chars)
      end

      def parse(input : String, pos : Int32)
        if pos >= input.size
          ParseFailure.new(pos, nil)
        elsif @disallowed_chars.includes?(input[pos])
          ParseFailure.new(pos, nil)
        else
          ParseSuccess.new(pos+1, nil)
        end
      end
    end

    class RepeatZeroOrMore
      def initialize(@p)
      end

      def parse(input : String, pos : Int32)
        prev_pos = pos

        loop do
          res = @p.parse(input, prev_pos)
          case res
          when ParseSuccess
            prev_pos = res.pos
          when ParseFailure
            break
          else
            raise "???"
          end
        end

        ParseSuccess.new(prev_pos, nil)
      end
    end

    class RepeatOneOrMore
      def initialize(@p)
      end

      def parse(input : String, pos : Int32)
        prev_pos = pos
        message = nil

        loop do
          res = @p.parse(input, prev_pos)
          case res
          when ParseSuccess
            prev_pos = res.pos
          when ParseFailure
            message = res.message
            break
          else
            raise "???"
          end
        end

        if prev_pos == pos
          ParseFailure.new(pos, message)
        else
          ParseSuccess.new(prev_pos, nil)
        end
      end
    end

    class Lazy
      def initialize(@block)
        @parser = nil
      end

      def parse(input : String, pos : Int32)
        parser = @parser
        if parser
          parser.parse(input, pos)
        else
          parser = @block.call
          @parser = parser
          parser.parse(input, pos)
        end
      end
    end

    class ErrorAnnotation
      def initialize(@message, @p)
      end

      def parse(input : String, pos : Int32)
        res = @p.parse(input, pos)
        case res
        when ParseSuccess
          res
        when ParseFailure
          ParseFailure.new(res.pos, @message)
        else
          raise "???"
        end
      end
    end
  end

  ###############################################################################

  module P
    def self.char(char)
      Parsers::Char.new(char)
    end

    def self.eof
      Parsers::EOF.new
    end

    def self.sequence(ps)
      Parsers::Sequence.new(ps)
    end

    def self.peek(p1)
      Parsers::Peek.new(p1)
    end

    def self.capture(name, p1)
      Parsers::Capture.new(name, p1)
    end

    def self.or(p1, p2)
      Parsers::Or.new(p1, p2)
    end

    def self.or(p1, p2, p3)
      Parsers::Or.new(
        p1,
        Parsers::Or.new(p2, p3),
      )
    end

    def self.repeat_zero_or_more(p1)
      Parsers::RepeatZeroOrMore.new(p1)
    end

    def self.repeat_one_or_more(p1)
      Parsers::RepeatOneOrMore.new(p1)
    end

    def self.all_but(chars)
      Parsers::AllBut.new(chars)
    end

    def self.lazy(&block : -> _)
      Parsers::Lazy.new(block)
    end

    def self.annotate_error(message, parser)
      Parsers::ErrorAnnotation.new(message, parser)
    end
  end

  module Px
    LowercaseChar = Parsers::Range.new(('a'..'z'))
    Digit = Parsers::Range.new(('0'..'9'))

    def self.lowercase_char
      LowercaseChar
    end

    def self.digit
      Digit
    end

    def self.identifier
      DMark::P.sequence(
        [
          lowercase_char,
          DMark::P.repeat_zero_or_more(
            DMark::P.or(
              lowercase_char,
              digit,
            )
          ),
        ]
      )
    end

    def self.lone_block
      DMark::P.sequence(
        [
          DMark::P.annotate_error("expected identifier", identifier),
          DMark::P.char('.'),
          DMark::P.or(
            DMark::P.peek(DMark::P.char('\n')),
            DMark::P.eof,
            DMark::P.sequence(
              [
                DMark::P.char(' '),
                inline_content,
              ]
            )
          )
        ]
      )
    end

    def self.inline_content
      DMark::P.repeat_zero_or_more(
        DMark::P.or(
          DMark::P.all_but(['%', '}', '\n']),
          DMark::P.lazy { inline_element },
        )
      )
    end

    def self.inline_element
      DMark::P.sequence(
        [
          DMark::P.char('%'),
          identifier,
          DMark::P.char('{'),
          DMark::P.lazy { inline_content as DMark::Parsers::RepeatZeroOrMore },
          DMark::P.char('}'),
        ]
      )
    end
  end
end
