module DMark
  class Parser
    class ParserError < StandardError
      attr_reader :line_nr
      attr_reader :col_nr

      def initialize(line_nr, col_nr, msg)
        @line_nr = line_nr
        @col_nr = col_nr
        @msg = msg

        super("parse error at line #{@line_nr + 1}, col #{@col_nr + 1}: #{@msg}")
      end
    end

    attr_reader :pos

    def initialize(input)
      @input = input
      @input_chars = @input.chars

      @pos = 0
      @col_nr = 0
      @line_nr = 0
    end

    def parse
      res = []

      loop do
        break if eof?

        blank_pos = try_read_blank_line
        break unless blank_pos

        @pos = blank_pos
        @line_nr += 1
        @col_nr = 0
      end

      loop do
        break if eof?
        res << read_block_with_children
      end

      res
    end

    ##########

    def peek_char(pos = @pos)
      if eof?
        nil
      else
        @input_chars[pos]
      end
    end

    def eof?(pos = @pos)
      pos >= @input_chars.size
    end

    def advance
      if !eof? && @input_chars[@pos] == "\n"
        @line_nr += 1
        @col_nr = 0
      end

      @pos += 1
      @col_nr += 1
    end

    def read_char(c)
      char = peek_char
      if char != c
        raise_parse_error("expected #{c.inspect}, but got #{char.nil? ? 'EOF' : char.inspect}")
      else
        advance
        char
      end
    end

    ##########

    def opt_read_char(c, cursor)
      if cursor.get == c
        Succ.new(cursor + 1, c)
      else
        Fail.new(cursor, "expected #{c.inspect}, but got #{cursor.get.nil? ? 'EOF' : cursor.get.inspect}")
      end
    end

    def opt_read_char_range(range, cursor)
      if range.cover?(cursor.get)
        Succ.new(cursor + 1, cursor.get)
      else
        Fail.new(cursor, "expected #{range}, not #{cursor.get.inspect}")
      end
    end

    def opt_read_identifier(cursor)
      opt_read_char_range('a'..'z', cursor).bind do |cursor, char|
        identifier = ''
        identifier << char
        loop do
          case cursor.get
          when 'a'..'z', '-', '0'..'9'
            identifier << cursor.get
            cursor = cursor.advance
          else
            break
          end
        end
        Succ.new(cursor, identifier)
      end
    end

    def opt_read_block_start(cursor)
      opt_read_char('#', cursor).bind do |cursor, _char|
        opt_read_identifier(cursor).bind do |cursor, identifier|
          Succ.new(cursor, identifier)
        end
      end
    end

    ##########

    def read_block_with_children(indentation = 0)
      res = read_single_block

      pending_blanks = 0
      until eof?
        blank_pos = try_read_blank_line
        if blank_pos
          @pos = blank_pos
          @line_nr += 1
          @col_nr = 0
          pending_blanks += 1
        else
          sub_indentation = detect_indentation
          break if sub_indentation < indentation + 1

          read_indentation(indentation + 1)
          if try_read_block_start
            res.children << read_block_with_children(indentation + 1)
          else
            res.children << "\n" unless res.children.empty?
            pending_blanks.times { res.children << "\n" }
            pending_blanks = 0

            res.children.concat(read_inline_content)
            read_end_of_inline_content
          end
        end
      end

      res
    end

    def try_read_blank_line
      pos = @pos

      loop do
        case peek_char(pos)
        when ' '
          pos += 1
        when nil
          break pos + 1
        when "\n"
          break pos + 1
        else
          break nil
        end
      end
    end

    def try_read_block_start
      opt_read_block_start(new_cursor).success?
    end

    def detect_indentation
      indentation_chars = 0
      pos = @pos

      loop do
        case peek_char(pos)
        when ' '
          pos += 1
          indentation_chars += 1
        else
          break
        end
      end

      indentation_chars / 2
    end

    def read_indentation(indentation)
      indentation.times do
        read_char(' ')
        read_char(' ')
      end
    end

    def read_single_block
      opt_read_block_start(new_cursor).bind_or_explode do |cursor, identifier|
        @pos = cursor.pos
        @line_nr = cursor.line_nr
        @col_nr = cursor.col_nr

        attributes =
          if peek_char == '['
            read_attributes
          else
            {}
          end

        case peek_char
        when nil, "\n"
          advance
          ElementNode.new(identifier, attributes, [])
        else
          read_char(' ')
          content = read_inline_content
          read_end_of_inline_content
          ElementNode.new(identifier, attributes, content)
        end
      end
    end

    def read_end_of_inline_content
      char = peek_char
      case char
      when "\n", nil
        advance
      when '}'
        raise_parse_error('unexpected } -- try escaping it as "%}"')
      else
        raise_parse_error('unexpected content')
      end
    end

    def read_identifier
      opt_read_identifier(new_cursor).bind_or_explode do |cursor, identifier|
        @pos = cursor.pos
        @line_nr = cursor.line_nr
        @col_nr = cursor.col_nr

        identifier
      end
    end

    def read_attributes
      read_char('[')

      res = {}

      at_start = true
      loop do
        char = peek_char
        case char
        when ']'
          advance
          break
        else
          read_char(',') unless at_start

          key = read_attribute_key
          if peek_char == '='
            read_char('=')
            value = read_attribute_value
          else
            value = key
          end

          res[key] = value

          at_start = false
        end
      end

      res
    end

    def read_attribute_key
      read_identifier
    end

    def read_attribute_value
      res = ''

      is_escaping = false
      loop do
        char = peek_char

        if is_escaping
          case char
          when '%', ']', ','
            advance
            res << char
            is_escaping = false
          when nil
            raise_parse_error('unexpected file end in attribute value')
          when "\n"
            raise_parse_error('unexpected line break in attribute value')
          else
            raise_parse_error(%(expected "%", "," or "]" after "%", but got #{char.inspect}))
          end
        else
          case char
          when ']', ','
            break
          when '%'
            advance
            is_escaping = true
          when nil
            raise_parse_error('unexpected file end in attribute value')
          when "\n"
            raise_parse_error('unexpected line break in attribute value')
          else
            advance
            res << char
          end
        end
      end

      res.to_s
    end

    def read_inline_content
      res = []

      loop do
        char = peek_char
        case char
        when "\n", nil
          break
        when '}'
          break
        when '%'
          advance
          res << read_percent_body
        else
          res << read_string
        end
      end

      res
    end

    def read_string
      res = ''

      loop do
        char = peek_char
        case char
        when nil, "\n", '%', '}'
          break
        else
          advance
          res << char
        end
      end

      res.to_s
    end

    def read_percent_body
      char = peek_char
      case char
      when '%', '}', '#'
        advance
        char.to_s
      when nil, "\n"
        raise_parse_error("expected something after %")
      else
        read_inline_element
      end
    end

    def read_inline_element
      name = read_identifier
      attributes =
        if peek_char == '['
          read_attributes
        else
          {}
        end
      read_char('{')
      contents = read_inline_content
      read_char('}')

      ElementNode.new(name, attributes, contents)
    end

    def raise_parse_error(msg)
      raise ParserError.new(@line_nr, @col_nr, msg)
    end

    # TODO: remove me
    def new_cursor
      Cursor.new(@input_chars, @pos, @line_nr, @col_nr)
    end
  end
end

require_relative 'parser/cursor'
require_relative 'parser/fail'
require_relative 'parser/succ'
