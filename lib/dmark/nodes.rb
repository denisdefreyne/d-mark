module DMark
  module Nodes
    class Node
      attr_reader :children

      def initialize
        @children = []
      end

      def inspect(_indent = 0)
        'Node()'
      end
    end

    class RootNode < Node
      def inspect(indent = 0)
        io = ''
        io << '  ' * indent
        io << 'Root('
        io << "\n" if children.any?
        children.each { |c| io << c.inspect(indent + 1) }
        io << '  ' * indent if children.any?
        io << ')'
        io << "\n"
        io
      end
    end

    class TextNode < Node
      attr_reader :text

      def initialize(text:)
        super()
        @text = text
      end

      def inspect(indent = 0)
        io = ''
        io << '  ' * indent
        io << 'Text('
        io << @text.inspect
        io << "\n" if children.any?
        children.each { |c| io << c.inspect(indent + 1) }
        io << '  ' * indent if children.any?
        io << ')'
        io << "\n"
        io
      end
    end

    class ElementNode < Node
      attr_reader :name

      def initialize(name:)
        super()
        @name = name
      end

      def inspect(indent = 0)
        io = ''
        io << '  ' * indent
        io << 'Element('
        io << @name
        io << "\n" if children.any?
        children.each { |c| io << c.inspect(indent + 1) }
        io << '  ' * indent if children.any?
        io << ')'
        io << "\n"
        io
      end
    end
  end
end
