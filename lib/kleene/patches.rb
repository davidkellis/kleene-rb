module Enumerable
  # calls the block with successive elements; returns the first truthy object returned by the block
  def find_map(&block)
    each do |element|
      mapped_value = block.call(element)
      return mapped_value if mapped_value
    end
    nil
  end

  def compact_map(&block)
    ary = []
    each do |e|
      v = block.call(e)
      unless v.nil?
        ary << v
      end
    end
    ary
  end

  alias_method :includes?, :include?
end
