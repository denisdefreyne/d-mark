module DMark
  class Translator
    attr_reader :out

    def initialize(nodes)
      @nodes = nodes

      @out = ''
    end

    def run
      @nodes.each do |node|
        handle(node)
      end
      @out
    end

    private

    def handle(_node)
      raise NotImplementedError
    end

    def handle_children(node)
      node.children.each { |child| handle(child) }
    end
  end
end
