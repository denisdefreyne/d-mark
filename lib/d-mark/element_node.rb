module DMark
  class ElementNode
    attr_reader :name
    attr_reader :attributes
    attr_reader :children

    def initialize(name, attributes, children)
      @name = name
      @attributes = attributes
      @children = children
    end

    def inspect
      io = ''
      io << 'Element(' << @name << ', '
      if @attributes.any?
        io << @attributes.inspect
        io << ', '
      end
      io << @children.inspect
      io << ')'
      io
    end

    def ==(other)
      case other
      when ElementNode
        @name == other.name &&
          @children == other.children &&
          @attributes == other.attributes
      else
        false
      end
    end
  end
end
