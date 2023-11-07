require "set"
require "stringio"
require_relative "./kleene"

module Kleene
  class NaiveOnlineRegex
    def initialize(regexen, window_size = 100)
      @regexen = regexen
      @window_size = window_size

      reset
    end

    def reset
      @buffer = ""
      @matches_per_regex = Hash.new   # Hash(Regexp, Set(MatchData))
    end

    # #ingest(input) is the online-style matching interface
    def ingest(input, debug = false) # : Set(OnlineMatch)
      @buffer << input
      new_online_matches = Set.new
      @regexen.each do |regex|
        existing_matches_for_regex = (@matches_per_regex[regex] ||= Set.new)
        scan_matches = @buffer.scan_matches(regex).to_set
        new_matches = scan_matches - existing_matches_for_regex   # new_matches : Set(MatchData)
        existing_matches_for_regex.merge(new_matches)
        new_online_matches.merge(new_matches.map {|match_data| OnlineMatch.new(regex, match_data) })
      end
      resize_buffer!
      new_online_matches
    end

    def matches # Hash(Regexp, Set(MatchData))
      @matches_per_regex
    end

    def matches_for(regex) # Set(MatchData) | Nil
      @matches_per_regex[regex]
    end

    def resize_buffer!
      if @buffer.size > @window_size
        @buffer = @buffer[-@window_size..-1]
      end
    end
  end

  # A {Regexp, MatchData} pair
  class OnlineMatch
    attr_reader :regex  # Regexp
    attr_reader :match  # MatchData
    def initialize(regex, match)
      @regex, @match = regex, match
    end
    def to_a
      @match.to_a
    end
    def to_h
      {@regex => to_a}
    end
  end
end
