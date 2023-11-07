
module Kleene
  class Parser
    def parse(pattern)
      ast = Regexp::Parser.parse(pattern)
      ast
    end
  end
end
