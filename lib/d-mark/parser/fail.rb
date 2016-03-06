module DMark
  class Parser
    class Fail
      attr_reader :cursor
      attr_reader :message

      def initialize(cursor, message)
        @cursor = cursor
        @message = message
      end

      def bind
        self
      end

      def bind_or_explode(&_block)
        explode
      end

      def success?
        false
      end

      # TODO: remove me
      def explode
        raise ParserError.new(cursor.line_nr, cursor.col_nr, message)
      end

      def inspect
        "Fail(#{message}, #{cursor.inspect})"
      end
    end
  end
end
