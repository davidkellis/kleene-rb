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
      ary << v unless v.nil?
    end
    ary
  end

  alias includes? include?
end

class String
  def scan_matches(pattern) # : Array(MatchData)
    to_enum(:scan, pattern).map { Regexp.last_match }
  end
end
