require 'treetop'

Treetop.load(File.dirname(__FILE__) + '/../../attributes_parser.treetop')

module DMark
  class Lexer
    INDENTATION = 2

    # @api private
    attr_accessor :pending_blanks

    # @api private
    attr_accessor :element_stack

    def initialize(string)
      @string = string

      @element_stack = []
      @tokens = []
      @pending_blanks = 0
    end

    class Line
      attr_reader :nr
      attr_reader :indentation
      attr_reader :data
      attr_reader :children

      def initialize(nr, indentation, data)
        @nr = nr
        @indentation = indentation
        @data = data

        @children = []
      end

      def inspect
        "<#{format '%-15s', self.class.name.split(/::/).last} ##{@nr} indent=#{@indentation.size} #{@data[0...40]}…>"
      end

      def print_tree(ind = 0)
        puts '  ' * ind + "#{self.class.name} #{@data[0...40]}"
        children.each { |c| c.print_tree(ind+2) }
      end
    end

    class EmptyLine < Line
      def initialize(line)
        super(line.nr, line.indentation, line.data)
      end
    end

    class BlockLine < Line
      attr_reader :element_name
      attr_reader :raw_attributes
      attr_reader :content

      def initialize(line, element_name, raw_attributes, content)
        super(line.nr, line.indentation, line.data)

        @element_name = element_name
        @raw_attributes = raw_attributes
        @content = content
      end
    end

    class ContentLine < Line
      def initialize(line)
        super(line.nr, line.indentation, line.data)
      end
    end

    def run
      # Get raw lines
      raw_lines = @string.lines.map.with_index do |line, line_nr|
        line =~ /^( *)($|[^ ].*)$/
        Line.new(line_nr, $1, $2)
      end

      # Categorise them
      lines = raw_lines.map do |line|
        case line.data
        when /^\s*$/
          EmptyLine.new(line)
        when /^([a-z][a-z0-9-]*)(\[(.*?)\])?\.($| .*$)/
          BlockLine.new(line, Regexp.last_match[1], Regexp.last_match[3], Regexp.last_match[4])
        when /^(.*)$/
          ContentLine.new(line)
        else
          raise line.inspect
        end
      end

      # Fix other line indentations to match preceding ones
      prev_indentation = ''
      lines.each do |line|
        case line
        when EmptyLine
          # ignore
        when BlockLine
          prev_indentation = line.indentation
        when ContentLine
          diff = line.indentation.size - prev_indentation.size - 2
          if diff > 0
            line.data[0,0] = ' ' * diff
            line.indentation[0...diff] = ''
          end
        end
      end

      # Nest them
      root_lines = [lines.first]
      stack = []
      prev_line = lines.first
      lines.each_cons(2) do |_a, b|
        case b
        when EmptyLine
          if stack.empty?
            root_lines << b
          else
            stack.last.children << b
          end
        when BlockLine, ContentLine
          if b.indentation.size > prev_line.indentation.size
            prev_line.children << b
            stack << prev_line
          elsif b.indentation.size == prev_line.indentation.size
            if stack.empty?
              root_lines << b
            else
              prev = stack.last
              prev.children << b
            end
          else
            while stack.size * 2 > b.indentation.size
              stack.pop
            end

            if stack.empty?
              root_lines << b
            else
              stack.last.children << b
            end
          end

          prev_line = b
        end
      end

      tokens = []
      pending_empty_lines = []

      root_lines.each do |line|
        handle_line_2(line, tokens, pending_empty_lines)
      end

      tokens
    end

    def handle_line_2(line, tokens, pending_empty_lines)
      case line
      when EmptyLine
        pending_empty_lines << line
      when BlockLine
        pending_empty_lines.each { |l| append_text(tokens, "\n") }
        pending_empty_lines.clear
        attributes = parse_attributes(line.raw_attributes, line.nr, 0)
        tokens << DMark::Tokens::TagBeginToken.new(name: line.element_name, attributes: attributes)
        if line.content
          tokens.concat(lex_inline(line.content, line.nr + 1))
        end
        line.children.each do |child_line|
          handle_line_2(child_line, tokens, pending_empty_lines)
        end
        tokens << DMark::Tokens::TagEndToken.new(name: line.element_name)
      when ContentLine
        pending_empty_lines.each { |l| append_text(tokens, "\n") }
        pending_empty_lines.clear
        tokens.concat(lex_inline(line.data + "\n", line.nr + 1))
      end
    end

    # @api private
    def parse_attributes(data, start_line_nr, start_col_nr)
      if data.nil?
        {}
      else
        parser = AttributesParser.new
        tree = parser.parse(data)
        if tree.nil?
          # FIXME: pass in full line
          raise LexerError.new(parser.failure_reason, data, start_line_nr + parser.failure_line, start_col_nr + parser.failure_column)
        end
        tree.value.each_with_object({}) do |pair, res|
          res[pair.first] = pair.last
        end
      end
    end

    # @api private
    def append_text(tokens, text)
      if tokens.empty? || !tokens.last.is_a?(DMark::Tokens::TextToken)
        tokens << DMark::Tokens::TextToken.new(text: text)
      else
        tokens.last.text << text
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

    # @api private
    def lex_inline(string, line_nr)
      stack = []
      state = :root
      tokens = []
      name = ''
      attributes = nil
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
            # FIXME: pass in col nr
            tokens << DMark::Tokens::TagBeginToken.new(
              name: name, attributes:
              parse_attributes(attributes, line_nr, 0))
            name = ''
            attributes = nil
          else
            raise LexerError.new("unexpected `#{char}` after `%`", string, line_nr, col_nr)
          end
        when :after_lbracket
          case char
          when ']'
            # FIXME: might make sense to have after_rbracket instead (to prevent %foo[a][b]{…})
            state = :after_pct
          else
            attributes ||= ''
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
