module DMark
  class Translator
    class UnhandledNode < StandardError
      attr_reader :node

      def initialize(node)
        super(message)
        @node = node
      end

      def message
        case @node
        when String
          'Unhandled string node'
        when DMark::ElementNode
          "Unhandled element node #{@node.name.inspect}"
        else
          "Unhandled node #{@node.inspect}"
        end
      end
    end

    def self.translate(nodes, context = {})
      new.translate(nodes, context)
    end

    def translate(nodes, context = {})
      [nodes.map { |node| handle(node, context) }].flatten.join
    end

    def handle(node, context = {})
      case node
      when String
        handle_string(node, context)
      when DMark::ElementNode
        handle_element(node, context)
      else
        raise ArgumentError, "Cannot handle #{node.class}"
      end
    end

    # @abstract
    def handle_string(string, _context)
      raise DMark::Translator::UnhandledNode.new(string)
    end

    # @abstract
    def handle_element(element, _context)
      raise DMark::Translator::UnhandledNode.new(element)
    end

    private

    def handle_children(node, context)
      node.children.map { |child| handle(child, context) }
    end
  end
end
