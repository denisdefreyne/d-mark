module DMark
  class Parser
    def initialize(tokens)
      @tokens = tokens

      @root_node = DMark::Nodes::RootNode.new
    end

    def run
      node_stack = [@root_node]

      @tokens.each do |token|
        case token
        when DMark::Tokens::TextToken
          node_stack.last.children << DMark::Nodes::TextNode.new(text: token.text)
        when DMark::Tokens::TagBeginToken
          new_node = DMark::Nodes::ElementNode.new(name: token.name, attributes: token.attributes)
          node_stack.last.children << new_node
          node_stack.push(new_node)
        when DMark::Tokens::TagEndToken
          node_stack.pop
        end
      end

      @root_node
    end
  end
end
