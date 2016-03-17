module DMark
  class Translator
    class UnhandledNode < StandardError
      attr_reader :node

      def initialize(node)
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
      new.translate(nodes, [], context)
    end

    def translate(nodes, path = [], context = {})
      [nodes.map { |node| handle(node, path, context) }].flatten.join('')
    end

    def translate_children(node, path, context = {})
      translate(node.children, path + [node], context)
    end

    def handle(node, path = [], context = {})
      case node
      when String
        handle_string(node, context)
      when DMark::ElementNode
        handle_element(node, path, context)
      else
        raise ArgumentError, "Cannot handle #{node.class}"
      end
    end

    # @abstract
    def handle_string(string, _context)
      raise DMark::Translator::UnhandledNode.new(string)
    end

    # @abstract
    def handle_element(element, _path, _context)
      raise DMark::Translator::UnhandledNode.new(element)
    end

    private

    def handle_children(node, path, context)
      new_path = path + [node]
      node.children.map { |child| handle(child, new_path, context) }
    end
  end
end
