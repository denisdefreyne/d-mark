module DMark
  class Parser
    class ParserError < Exception
      def initialize(@pos, @msg)
        super("parse error at #{@pos}: #{@msg}")
      end
    end

    class ElementNode
      getter :name
      getter :children

      def initialize(@name, @children)
      end

      def inspect(io)
        io << "Element(" << @name << ", "
        @children.inspect(io)
        io << ")"
      end

      def ==(other)
        case other
        when ElementNode
          @name == other.name && @children == other.children
        else
          false
        end
      end
    end

    getter :pos

    def initialize(@input)
      @pos = 0
    end

    def parse
      res = [] of ElementNode

      loop do
        if eof?
          break
        else
          res << read_block_with_children
        end
      end

      res
    end

    ##########

    def peek_char
      if eof?
        '\0'
      else
        @input[@pos]
      end
    end

    def eof?
      @pos >= @input.size
    end

    def advance
      @pos += 1
    end

    def read_char(c)
      char = peek_char
      if char != c
        raise ParserError.new(@pos, "expected #{c.inspect}, but got #{char.inspect}")
      else
        advance
        char
      end
    end

    ##########

    def read_block_with_children
      read_single_block
    end

    def read_single_block
      identifier = read_identifier
      read_char('.')

      case peek_char
      when '\0', '\n'
        ElementNode.new(identifier, [] of ElementNode | String)
      else
        read_char(' ')
        content = read_inline_content
        read_end_of_inline_content
        ElementNode.new(identifier, content)
      end
    end

    def read_end_of_inline_content
      char = peek_char
      case char
      when '\n', '\0'
        advance
      when '}'
        raise ParserError.new(@pos, "unexpected } -- try escaping it as \"%}\"")
      else
        raise ParserError.new(@pos, "unexpected content")
      end
    end

    def read_identifier
      a = read_identifier_head
      b = read_identifier_tail
      "#{a}#{b}"
    end

    def read_identifier_head
      char = peek_char
      case char
      when 'a'..'z'
        advance
        char
      else
        raise ParserError.new(@pos, "expected an identifier after %, but got #{char.inspect}")
      end
    end

    def read_identifier_tail
      res = MemoryIO.new

      loop do
        char = peek_char
        case char
        when 'a'..'z', '-', '0'..'9'
          advance
          res << char
        else
          break
        end
      end

      res.to_s
    end

    def read_inline_content
      res = [] of String | ElementNode

      loop do
        char = peek_char
        case char
        when '\n', '\0'
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
      res = MemoryIO.new

      loop do
        char = peek_char
        case char
        when '\0', '\n', '%', '}'
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
      when '%', '}'
        advance
        char.to_s
      when '\0', '\n'
        raise ParserError.new(@pos, "expected something after %")
      else
        read_inline_element
      end
    end

    def read_inline_element
      name = read_identifier
      read_char('{')
      contents = read_inline_content
      read_char('}')

      ElementNode.new(name, contents)
    end
  end
end
