module DMark
  class Lexer
    INDENTATION = 2

    def initialize(string)
      @string = string

      @element_stack = []
      @tokens = []
      @pending_blanks = 0
    end

    def run
      @string.lines.each_with_index do |line, line_nr|
        handle_line(line, line_nr)
      end

      unwind_stack_until(0)

      @tokens
    end

    private

    def handle_line(line, line_nr)
      case line
      when /^\s+$/
        handle_blank_line(line_nr)
      when /^(\s*)([a-z0-9-]+)(\[(.*?)\])?\.\s*$/
        indentation = Regexp.last_match[1]
        element_name = Regexp.last_match[2]
        raw_attributes = Regexp.last_match[4]

        handle_block_line_without_content(line_nr, indentation, element_name, raw_attributes)
      when /^(\s*)([a-z0-9-]+)(\[(.*?)\])?\. (.*)$/
        indentation = Regexp.last_match[1]
        element_name = Regexp.last_match[2]
        raw_attributes = Regexp.last_match[4]
        content = Regexp.last_match[5]

        handle_block_line_with_content(line_nr, indentation, element_name, raw_attributes, content)
      when /^(\s*)(.*)$/
        indentation = Regexp.last_match[1]
        content = Regexp.last_match[2]

        handle_other_line(line_nr, indentation, content)
      end
    end

    def handle_blank_line(line_nr)
      @pending_blanks += 1
    end

    def handle_block_line_without_content(_line_nr, indentation, element_name, raw_attributes)
      attributes = parse_attributes(raw_attributes)

      unwind_stack_until(indentation.size)

      @element_stack << element_name
      @tokens << DMark::Tokens::TagBeginToken.new(name: element_name, attributes: attributes)
    end

    def handle_block_line_with_content(line_nr, indentation, element_name, raw_attributes, content)
      attributes = parse_attributes(raw_attributes)

      unwind_stack_until(indentation.size)

      @tokens << DMark::Tokens::TagBeginToken.new(name: element_name, attributes: attributes)
      @tokens.concat(lex_inline(content, line_nr + 1))
      @tokens << DMark::Tokens::TagEndToken.new(name: element_name)
    end

    def handle_other_line(line_nr, indentation, content)
      unwind_stack_until(indentation.size)

      if @element_stack.empty?
        # FIXME: unify format of messages (uppercase, lowercase, …)
        raise LexerError.new("Can’t insert raw content at root level", line, line_nr, 1)
      end

      extra_indentation = [indentation.size - INDENTATION * @element_stack.size, 0].max

      @tokens.concat(lex_inline(' ' * extra_indentation + content + "\n", line_nr + 1))
    end

    def parse_attributes(data)
      # FIXME: write a proper parser

      (data || '').split(',').map { |part| part.split('=') }.each_with_object({}) do |pair, res|
        res[pair.first] = pair.last || pair.first
      end
    end

    def unwind_stack_until(num)
      while @element_stack.size * INDENTATION > num
        elem = @element_stack.pop

        @tokens << DMark::Tokens::TagEndToken.new(name: elem)
      end

      append_text(@tokens, "\n" * @pending_blanks)
      @pending_blanks = 0
    end

    def append_text(out, text)
      if out.empty? || !out.last.is_a?(DMark::Tokens::TextToken)
        out << DMark::Tokens::TextToken.new(text: text)
      else
        out.last.text << text
      end
    end

    class LexerError < StandardError
      def initialize(message, line, line_nr, col_nr)
        @message = message
        @line = line
        @line_nr = line_nr
        @col_nr = col_nr
      end

      class Coloriser
        def red
          "\e[31m".freeze
        end

        def bold
          "\e[1m".freeze
        end

        def reset
          "\e[0m".freeze
        end
      end

      class NullColoriser
        def red
          ''.freeze
        end

        def bold
          ''.freeze
        end

        def reset
          ''.freeze
        end
      end

      def message
        formatted_message(NullColoriser.new)
      end

      def message_for_tty
        formatted_message(Coloriser.new)
      end

      def formatted_message(coloriser)
        line_excerpt_start = [@col_nr - 38, 0].max
        line_excerpt_end = @col_nr + 38
        line_excerpt = @line[line_excerpt_start..line_excerpt_end]

        if line_excerpt_start > 0
          line_excerpt[0] = '…'
        end

        if line_excerpt_end < @line.size
          line_excerpt[-1] = '…'
        end

        [
          "#{coloriser.red}#{coloriser.bold}ERROR#{coloriser.reset} (line #{@line_nr}, col #{@col_nr}): #{coloriser.red}#{@message}#{coloriser.reset}",
          '',
          line_excerpt,
          coloriser.red + ' ' * (@col_nr - 1 - line_excerpt_start) + '^' + coloriser.reset,
          '',
        ].join("\n")
      end
    end

    def lex_inline(string, line_nr)
      stack = []
      state = :root
      tokens = []
      name = ''
      attributes = ''
      col_nr = 0

      string.chars.each_with_index do |char|
        col_nr += 1

        case state
        when :root
          case char
          when '%'
            state = :after_pct
          when '}'
            if stack.empty?
              message = 'Unexpected `}`. Try escaping it as `%}`.'
              raise LexerError.new(message, string, line_nr, col_nr)
            else
              data = stack.pop
              case data.first
              when :raw
                append_text(tokens, data.last)
              when :elem
                tokens << DMark::Tokens::TagEndToken.new(name: data.last)
              else
                raise "Unexpected entry on stack: #{data.inspect}"
              end
            end
          else
            append_text(tokens, char)
          end
        when :after_pct
          # FIXME: require at least one character after %

          case char
          when 'a'..'z', '0'..'9', '-'
            name << char
          when '%' # escaped
            state = :root
            col_nr -= 1
            append_text(tokens, '%')
          when '}' # escaped
            state = :root
            col_nr -= 1
            append_text(tokens, '}')
          when '['
            state = :after_lbracket
          when '{'
            state = :root
            stack << [:elem, name]
            tokens << DMark::Tokens::TagBeginToken.new(name: name, attributes: parse_attributes(attributes))
            name = ''
            attributes = ''
          else
            raise LexerError.new("unexpected `#{char}` after `%`", string, line_nr, col_nr)
          end
        when :after_lbracket
          case char
          when ']'
            # FIXME: might make sense to have after_rbracket instead (to prevent %foo[a][b]{…})
            state = :after_pct
          else
            attributes << char
          end
        else
          raise "Unexpected state: #{state.inspect}"
        end
      end

      tokens
    end
  end
end
