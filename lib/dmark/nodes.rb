class Node
  attr_reader :children

  def initialize(children:)
    @children = children
  end

  def to_s
    raise NotImplementedError
  end
end

class RootNode < Node
  def to_s
    children.map(&:to_s).join
  end
end

class TextNode < Node
  attr_reader :text

  def initialize(text:)
    @text = text
  end

  def to_s
    @text
  end
end

class ElementNode < Node
  attr_reader :name

  def initialize(name:)
    @name = name
  end

  def to_s
    "<#{translate_elem_name(name)}>#{super}</#{translate_elem_name(name)}>"
  end
end
