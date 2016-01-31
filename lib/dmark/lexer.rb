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
        case line
        when /^\s+$/
          # blank line
          @pending_blanks += 1
        when /^(\s*)([a-z0-9-]+)(\[.*?\])?\.\s*$/
          # empty element
          indentation = $1
          element = $2
          options = $3

          unwind_stack_until(indentation.size)

          @element_stack << element
          @tokens << DMark::Tokens::TagBeginToken.new(name: element)
        when /^(\s*)([a-z0-9-]+)(\[.*?\])?\. (.*)$/
          # element with inline content
          indentation = $1
          element = $2
          options = $3
          data = $4

          unwind_stack_until(indentation.size)

          @tokens << DMark::Tokens::TagBeginToken.new(name: element)
          @tokens.concat(lex_inline(data, line_nr + 1))
          @tokens << DMark::Tokens::TagEndToken.new(name: element)
        when /^(\s*)(.*)$/
          # other line (e.g. data)
          indentation = $1
          data = $2

          unwind_stack_until(indentation.size)

          if @element_stack.empty?
            raise "Can’t insert raw data at root level"
          end

          append_text(@tokens, data + "\n")
        end
      end

      unwind_stack_until(0)

      @tokens
    end

    private

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

      BOLD = "\e[1m"
      RED = "\e[31m"
      RESET = "\e[0m"

      def message
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
          "#{RED}#{BOLD}ERROR#{RESET} (line #{@line_nr}, col #{@col_nr}): #{RED}#{@message}#{RESET}",
          '',
          line_excerpt,
          RED + ' ' * (@col_nr - 1 - line_excerpt_start) + '^' + RESET,
          '',
        ].join("\n")
      end
    end

    def lex_inline(string, line_nr)
      stack = []
      state = :root
      tokens = []
      name = ''
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
          when '{'
            state = :root
            stack << [:elem, name]
            tokens << DMark::Tokens::TagBeginToken.new(name: name)
            name = ''
          else
            raise "line #{line_nr + 1}, col #{col_nr + 1}: unexpected `#{char}` after %"
          end
        else
          raise "Unexpected state: #{state.inspect}"
        end
      end

      tokens
    end
  end
end