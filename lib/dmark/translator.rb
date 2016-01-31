module DMark
  class Translator
    attr_reader :out

    def initialize(tree)
      @tree = tree

      @out = ''
    end

    def run
      handle(@tree)
      @out
    end

    private

    def handle(node)
      raise NotImplementedError
    end

    def handle_children(node)
      node.children.each { |child| handle(child) }
    end
  end
end
