module DMark
  class Parser
    class Succ
      attr_reader :cursor
      attr_reader :data

      def initialize(cursor, data)
        @cursor = cursor
        @data = data
      end

      def bind
        yield(cursor, data)
      end

      # TODO: remove me
      def bind_or_explode(&block)
        bind(&block)
      end

      def success?
        true
      end

      def inspect
        "Succ(#{cursor.inspect}, #{data.inspect})"
      end
    end
  end
end
