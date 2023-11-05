require_relative "./spec_helper"

include Kleene
include DSL

describe OnlineDFA do
  it "has an online matching interface" do
    alphabet = Set['a', 'b', 'z']
    a_star = kleene(literal("a", alphabet))
    odfa = OnlineDFA.new([a_star])

    input_string = "abaabaaa"

    odfa.reset

    odfa.ingest "ab"
    odfa.matches.should eq({
      a_star => [
        MatchRef.new("ab", 0...0),
        MatchRef.new("ab", 1...1),
        MatchRef.new("ab", 0..0)
      ]
    })

    odfa.ingest "aa"
    odfa.matches.should eq({
      a_star => [
        MatchRef.new("abaa", 0...0),
        MatchRef.new("abaa", 1...1),
        MatchRef.new("abaa", 0..0),
        MatchRef.new("abaa", 2...2),
        MatchRef.new("abaa", 3...3),
        MatchRef.new("abaa", 2..2),
        MatchRef.new("abaa", 2..3),
        MatchRef.new("abaa", 3..3)
      ]
    })

    odfa.reset

    odfa.ingest "b"
    odfa.matches.should eq({
      a_star => [
        MatchRef.new("b", 0...0),
      ]
    })

    odfa.ingest ""
    odfa.matches.should eq({
      a_star => [
        MatchRef.new("b", 0...0),
      ]
    })

    odfa.ingest "a"
    odfa.matches.should eq({
      a_star => [
        MatchRef.new("ba", 0...0),
        MatchRef.new("ba", 1...1),
        MatchRef.new("ba", 1..1),
      ]
    })

    odfa.ingest "aa", true
    odfa.matches.should eq({
      a_star => [
        MatchRef.new("baaa", 0...0),
        MatchRef.new("baaa", 1...1),
        MatchRef.new("baaa", 1..1),
        MatchRef.new("baaa", 2...2),
        MatchRef.new("baaa", 3...3),
        MatchRef.new("baaa", 1..2),
        MatchRef.new("baaa", 2..2),
        MatchRef.new("baaa", 1..3),
        MatchRef.new("baaa", 2..3),
        MatchRef.new("baaa", 3..3),
      ]
    })

  end
end
