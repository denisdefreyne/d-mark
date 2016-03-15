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

    def self.translate(nodes)
      new.translate(nodes)
    end

    def translate(nodes, path = [])
      [nodes.map { |node| handle(node, path) }].flatten.join('')
    end

    def translate_children(node, path)
      translate(node.children, path + [node])
    end

    def handle(node, path = [])
      case node
      when String
        handle_string(node)
      when DMark::ElementNode
        handle_element(node, path)
      else
        raise ArgumentError, "Cannot handle #{node.class}"
      end
    end

    # @abstract
    def handle_string(string)
      raise DMark::Translator::UnhandledNode.new(string)
    end

    # @abstract
    def handle_element(element, _path)
      raise DMark::Translator::UnhandledNode.new(element)
    end

    private

    def handle_children(node, path)
      new_path = path + [node]
      node.children.map { |child| handle(child, new_path) }
    end
  end
end
