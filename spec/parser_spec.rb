require_relative "./spec_helper"

include Kleene
include DSL

describe Kleene do
  describe Parser do
    it "builds an NFA from a regex pattern" do
      parser = Parser.new

      # nfa = parser.parse(/foo/)
      # nfa.should eq('foo')
    end
  end
end
