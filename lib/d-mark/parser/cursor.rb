module DMark
  class Parser
    class Cursor
      attr_reader :str
      attr_reader :pos
      attr_reader :line_nr
      attr_reader :col_nr

      def initialize(str, pos, line_nr, col_nr)
        @str = str
        @pos = pos
        @line_nr = line_nr
        @col_nr = col_nr
      end

      def get
        @str[@pos]
      end

      def +(other)
        # FIXME: incorrect!

        case get
        when "\n"
          self.class.new(str, pos + other, line_nr + 1, 0)
        else
          self.class.new(str, pos + other, line_nr, col_nr + other)
        end
      end

      def advance
        self + 1
      end

      def inspect
        "Cursor(#{line_nr + 1}:#{col_nr + 1}; #{pos})"
      end
    end
  end
end
