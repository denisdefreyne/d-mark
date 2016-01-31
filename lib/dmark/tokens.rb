module DMark
  module Tokens
    class Token
      def to_s
        raise NotImplementedError
      end
    end

    class TextToken < Token
      attr_reader :text

      def initialize(text:)
        @text = text
      end

      def to_s
        "Text(#{@text.inspect})"
      end
    end

    class AbstractTagToken < Token
      attr_reader :name

      def initialize(name:)
        @name = name
      end
    end

    class TagBeginToken < AbstractTagToken
      def to_s
        "TagBegin(#{name.inspect})"
      end
    end

    class TagEndToken < AbstractTagToken
      def to_s
        "TagEnd(#{name.inspect})"
      end
    end
  end
end
