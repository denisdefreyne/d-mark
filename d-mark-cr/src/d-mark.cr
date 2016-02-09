module DMark
  struct ParseSuccess
    getter :pos
    getter :captures
    getter :cut

    def initialize(@pos : Int32, @captures, @cut = 0)
    end
  end

  struct ParseFailure
    getter :pos
    getter :message
    getter :cut

    def initialize(@pos : Int32, @message, @cut = 0)
    end
  end

  module Parsers
    struct Char
      def initialize(@char)
      end

      def parse(input : String, pos : Int32)
        res =
          if pos >= input.size
            ParseFailure.new(pos, nil)
          elsif input[pos] == @char
            ParseSuccess.new(pos+1, nil)
          else
            ParseFailure.new(pos, nil)
          end

        # puts "[#{self.class.name}] #{res.inspect}"

        res
      end
    end

    struct EOF
      def initialize
      end

      def parse(input : String, pos : Int32)
        res =
          if pos == input.size
            ParseSuccess.new(pos, nil)
          else
            ParseFailure.new(pos, nil)
          end

        # puts "[#{self.class.name}] #{res.inspect}"

        res
      end
    end

    struct Cut
      def parse(input : String, pos : Int32)
        res = ParseSuccess.new(pos, nil, pos)
        # puts "[#{self.class.name}] #{res.inspect}"
        res
      end
    end

    struct Sequence
      def initialize(@ps)
      end

      def parse(input : String, pos : Int32)
        prev_pos = pos
        captures = {} of Symbol => String | Array(String)
        cut = 0

        @ps.each do |p1|
          res = p1.parse(input, prev_pos)
          # puts "[#{self.class.name}] (tmp) #{res.inspect}"
          cut = [cut, res.cut].max
          case res
          when ParseSuccess
            prev_pos = res.pos
            res_captures = res.captures
            if res_captures
              captures = captures.merge(res_captures)
            end
          when ParseFailure
            res = ParseFailure.new(res.pos, res.message, cut)
            # puts "[#{self.class.name}] (final) #{res.inspect}"
            return res
          else
            raise "???"
          end
        end

        res = ParseSuccess.new(prev_pos, captures, cut)
        # puts "[#{self.class.name}] (final) #{res.inspect}"
        res
      end
    end

    struct Capture
      def initialize(@name, @p)
      end

      def parse(input : String, pos : Int32)
        res = @p.parse(input, pos)
        # puts "[#{self.class.name}] #{res.inspect}"
        case res
        when ParseSuccess
          capture = input[pos...res.pos]
          captures = res.captures || {} of Symbol => String | Array(String)
          ParseSuccess.new(res.pos, captures.merge({ @name => capture }))
        when ParseFailure
          res
        else
          raise "???"
        end
      end
    end

    class And
      def initialize(@p1, @p2)
      end

      def parse(input : String, pos : Int32)
        res = @p1.parse(input, pos)
        # puts "[#{self.class.name}] #{res.inspect}"
        case res
        when ParseSuccess
          # FIXME: handle captures
          @p2.parse(input, res.pos)
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
        res = @p1.parse(input, pos)
        # puts "[#{self.class.name}] #{res.inspect}"
        case res
        when ParseSuccess
          res
        when ParseFailure
          if pos < res.cut
            res
          else
            @p2.parse(input, pos)
          end
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
        # puts "[#{self.class.name}] #{res.inspect}"
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
        res =
          if pos >= input.size
            ParseFailure.new(pos, nil)
          elsif @range.includes?(input[pos])
            ParseSuccess.new(pos+1, nil)
          else
            ParseFailure.new(pos, nil)
          end

        # puts "[#{self.class.name}] #{res.inspect}"

        res
      end
    end

    struct AllBut
      def initialize(@disallowed_chars)
      end

      def parse(input : String, pos : Int32)
        res =
          if pos >= input.size
            ParseFailure.new(pos, nil)
          elsif @disallowed_chars.includes?(input[pos])
            ParseFailure.new(pos, nil)
          else
            ParseSuccess.new(pos+1, nil)
          end

        # puts "[#{self.class.name}] #{res.inspect}"

        res
      end
    end

    class RepeatZeroOrMore
      def initialize(@p)
      end

      def parse(input : String, pos : Int32)
        prev_pos = pos
        cut = 0

        loop do
          res = @p.parse(input, prev_pos)
          # puts "[#{self.class.name}] #{res.inspect}"
          cut = [cut, res.cut].max
          case res
          when ParseSuccess
            prev_pos = res.pos
          when ParseFailure
            if prev_pos < cut
              return ParseFailure.new(res.pos, res.message, cut)
            else
              break
            end
          else
            raise "???"
          end
        end

        ParseSuccess.new(prev_pos, nil, cut)
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
        # puts "[#{self.class.name}] #{res.inspect}"
        case res
        when ParseSuccess
          res
        when ParseFailure
          ParseFailure.new(res.pos, @message, res.cut)
        else
          raise "???"
        end
      end
    end

    class Trace
      def initialize(@message)
      end

      def parse(input : String, pos : Int32)
        puts "[trace] @#{pos} #{@message}"
        ParseSuccess.new(pos, nil)
      end
    end
  end

  ###############################################################################

  module P
    def self.cut
      Parsers::Cut.new
    end

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
      or(p1, or(p2, p3))
    end

    def self.or(p1, p2, p3, p4)
      or(p1, or(p2, p3, p4))
    end

    def self.or(p1, p2, p3, p4, p5)
      or(p1, or(p2, p3, p4, p5))
    end

    def self.and(p1, p2)
      Parsers::And.new(p1, p2)
    end

    def self.repeat_zero_or_more(p1)
      Parsers::RepeatZeroOrMore.new(p1)
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

    def self.trace(message)
      Parsers::Trace.new(message)
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
          DMark::P.capture(:name,
            DMark::P.annotate_error("expected identifier at beginning of block",
              identifier)),
          DMark::P.annotate_error("expected period after identifier",
            DMark::P.char('.')),
          DMark::P.or(
            DMark::P.peek(DMark::P.char('\n')),
            DMark::P.eof,
            DMark::P.sequence(
              [
                DMark::P.char(' '),
                DMark::P.trace("start of inline content"),
                inline_content,
                DMark::P.trace("end of inline content"),
                DMark::P.peek(
                  DMark::P.or(
                    DMark::P.char('\n'),
                    DMark::P.eof)),
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
          DMark::P.and(DMark::P.char('%'), DMark::P.char('%')),
          DMark::P.and(DMark::P.char('%'), DMark::P.char('}')),
          DMark::P.lazy { inline_element },
        )
      )
    end

    def self.inline_element
      DMark::P.sequence(
        [
          DMark::P.char('%'),
          DMark::P.cut,
          DMark::P.capture(:name,
            DMark::P.annotate_error("expected identifier after %",
              identifier)),
          # DMark::P.trace("end of identifier"),
          DMark::P.cut,
          DMark::P.annotate_error("expected { after identifier",
            DMark::P.char('{')),
          DMark::P.lazy { inline_content as DMark::Parsers::RepeatZeroOrMore },
          DMark::P.char('}'),
        ]
      )
    end
  end
end
