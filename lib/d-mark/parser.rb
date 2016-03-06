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

        blank_line_res = opt_read_blank_line(new_cursor)
        case blank_line_res
        when Succ
          sync_cursor(blank_line_res.cursor)
        when Fail
          break
        end
      end

      loop do
        break if eof?
        res << read_block_with_children
      end

      res
    end

    ##########

    def eof?(pos = @pos)
      pos >= @input_chars.size
    end

    ##########

    def opt_read_char(c, cursor)
      if cursor.get == c
        Succ.new(cursor.advance, c)
      else
        Fail.new(cursor, "expected #{c.inspect}, but got #{cursor.get.nil? ? 'EOF' : cursor.get.inspect}")
      end
    end

    def opt_read_string(string, cursor)
      string.each_char do |c|
        if cursor.get == c
          cursor = cursor.advance
        else
          return Fail.new(cursor, nil)
        end
      end
      Succ.new(cursor, nil)
    end

    def opt_read_char_range(range, cursor)
      if range.cover?(cursor.get)
        Succ.new(cursor.advance, cursor.get)
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

    def opt_read_until(chars, cursor)
      res = ''

      loop do
        char = cursor.get
        break if chars.include?(char)
        cursor = cursor.advance
        res << char
      end

      Succ.new(cursor, res)
    end

    def opt_read_block_start(cursor)
      opt_read_char('#', cursor).bind do |cursor, _char|
        opt_read_identifier(cursor).bind do |cursor, identifier|
          Succ.new(cursor, identifier)
        end
      end
    end

    def opt_read_attributes(cursor)
      case cursor.get
      when '['
        opt_read_attribute_pairs(cursor.advance)
      else
        Succ.new(cursor, {})
      end
    end

    def opt_read_attribute_pairs(cursor)
      case cursor.get
      when ']'
        Succ.new(cursor.advance, {})
      else
        opt_read_attribute_pair(cursor).bind do |cursor, pair|
          opt_read_attribute_pairs_tail(cursor, pair)
        end
      end
    end

    def opt_read_attribute_pairs_tail(cursor, pairs)
      case cursor.get
      when ']'
        Succ.new(cursor.advance, pairs)
      else
        opt_read_char(',', cursor).bind do |cursor, _|
          opt_read_attribute_pair(cursor).bind do |cursor, pair|
            opt_read_attribute_pairs_tail(cursor, pairs.merge(pair))
          end
        end
      end
    end

    def opt_read_attribute_pair(cursor)
      opt_read_identifier(cursor).bind do |cursor, key|
        eq = opt_read_char('=', cursor)

        case eq
        when Fail
          Succ.new(eq.cursor, { key => key })
        when Succ
          opt_read_attribute_value(eq.cursor).bind do |cursor, value|
            Succ.new(cursor, { key => value })
          end
        end
      end
    end

    def opt_read_attribute_value(cursor)
      res = ''

      is_escaping = false
      loop do
        char = cursor.get

        if is_escaping
          case char
          when '%', ']', ','
            cursor = cursor.advance
            res << char
            is_escaping = false
          when nil
            return Fail.new(cursor, 'unexpected file end in attribute value')
          when "\n"
            return Fail.new(cursor, 'unexpected line break in attribute value')
          else
            return Fail.new(cursor, %(expected "%", "," or "]" after "%", but got #{char.inspect}))
          end
        else
          case char
          when ']', ','
            break
          when '%'
            cursor = cursor.advance
            is_escaping = true
          when nil
            return Fail.new(cursor, 'unexpected file end in attribute value')
          when "\n"
            return Fail.new(cursor, 'unexpected line break in attribute value')
          else
            cursor = cursor.advance
            res << char
          end
        end
      end

      Succ.new(cursor, res)
    end

    def opt_read_inline_content(cursor)
      contents = []

      loop do
        case cursor.get
        when "\n", nil
          break
        when '}'
          break
        when '%'
          cursor = cursor.advance
          elem_res = opt_read_percent_body(cursor)
          case elem_res
          when Succ
            contents << elem_res.data
            cursor = elem_res.cursor
          when Fail
            return elem_res
          end
        else
          string_res = opt_read_until([nil, "\n", '%', '}'], cursor)
          case string_res
          when Succ
            contents << string_res.data
            cursor = string_res.cursor
          when Fail
            return string_res
          end
        end
      end

      Succ.new(cursor, contents)
    end

    def opt_read_percent_body(cursor)
      case cursor.get
      when '%', '}', '#'
        Succ.new(cursor.advance, cursor.get)
      when nil, "\n"
        Fail.new(cursor, "expected something after %")
      else
        opt_read_inline_element(cursor)
      end
    end

    def opt_read_inline_element(cursor)
      opt_read_identifier(cursor).bind do |cursor, name|
        opt_read_attributes(cursor).bind do |cursor, attributes|
          opt_read_char('{', cursor).bind do |cursor, _|
            opt_read_inline_content(cursor).bind do |cursor, contents|
              opt_read_char('}', cursor).bind do |cursor, _|
                Succ.new(cursor, ElementNode.new(name, attributes, contents))
              end
            end
          end
        end
      end
    end

    def opt_read_single_block(cursor)
      opt_read_block_start(cursor).bind do |cursor, identifier|
        opt_read_attributes(cursor).bind do |cursor, attributes|
          case cursor.get
          when nil, "\n"
            Succ.new(cursor.advance, ElementNode.new(identifier, attributes, []))
          else
            opt_read_char(' ', cursor).bind do |cursor, _|
              opt_read_inline_content(cursor).bind do |cursor, content|
                opt_read_end_of_inline_content(cursor).bind do |cursor, _|
                  Succ.new(cursor, ElementNode.new(identifier, attributes, content))
                end
              end
            end
          end
        end
      end
    end

    def opt_read_end_of_inline_content(cursor)
      case cursor.get
      when "\n", nil
        Succ.new(cursor.advance, nil)
      when '}'
        Fail.new(cursor, 'unexpected } -- try escaping it as "%}"')
      else
        Fail.new(cursor, 'unexpected content')
      end
    end

    def opt_read_blank_line(cursor)
      loop do
        case cursor.get
        when ' '
          cursor = cursor.advance
        when nil
          break Succ.new(cursor.advance, nil)
        when "\n"
          break Succ.new(cursor.advance, nil)
        else
          break Fail.new(cursor, nil)
        end
      end
    end

    ##########

    def read_block_with_children(indentation = 0)
      opt_read_single_block(new_cursor).bind_or_explode do |cursor, res|
        sync_cursor(cursor)

        pending_blanks = 0
        until eof?
          blank_line_res = opt_read_blank_line(new_cursor)
          case blank_line_res
          when Succ
            sync_cursor(blank_line_res.cursor)
            pending_blanks += 1
          when Fail
            sub_indentation = opt_detect_indentation(new_cursor)
            break if sub_indentation < indentation + 1

            opt_read_string('  ' * (indentation + 1), new_cursor).bind_or_explode do |cursor, _|
              sync_cursor(cursor)
              block_start = opt_read_block_start(cursor)
              case block_start
              when Succ
                res.children << read_block_with_children(indentation + 1)
              when Fail
                res.children << "\n" unless res.children.empty?
                pending_blanks.times { res.children << "\n" }
                pending_blanks = 0

                opt_read_inline_content(new_cursor).bind_or_explode do |cursor, contents|
                  sync_cursor(cursor)
                  res.children.concat(contents)
                  opt_read_end_of_inline_content(new_cursor).bind_or_explode do |cursor, _|
                    sync_cursor(cursor)
                    nil
                  end
                end
              end
            end
          end
        end

        res
      end
    end

    def opt_detect_indentation(cursor)
      indentation_chars = 0

      loop do
        case cursor.get
        when ' '
          cursor = cursor.advance
          indentation_chars += 1
        else
          break
        end
      end

      indentation_chars / 2
    end

    # TODO: remove me
    def new_cursor
      Cursor.new(@input_chars, @pos, @line_nr, @col_nr)
    end

    # TODO: remove me
    def sync_cursor(cursor)
      @pos = cursor.pos
      @line_nr = cursor.line_nr
      @col_nr = cursor.col_nr
    end
  end
end

require_relative 'parser/cursor'
require_relative 'parser/fail'
require_relative 'parser/succ'
