require 'set'
require_relative './kleene'

module Kleene
  class NaiveOnlineRegex
    def initialize(regexen, window_size = 100)
      @regexen = regexen
      @window_size = window_size

      reset
    end

    def reset
      @buffer = ''
      @matches_per_regex = {} # Hash(Regexp, Set(OnlineMatch))
    end

    # #ingest(input) is the online-style matching interface
    def ingest(input, _debug = false) # : Set(OnlineMatch)
      @buffer << input
      new_online_matches = Set.new
      @regexen.each do |regex|
        existing_matches_for_regex = (@matches_per_regex[regex] ||= Set.new)
        scan_matches = @buffer.scan_matches(regex)
        scan_online_matches = scan_matches.map {|match_data| OnlineMatch.new(regex, match_data) }.to_set
        new_matches = scan_online_matches - existing_matches_for_regex # new_matches : Set(OnlineMatch)
        existing_matches_for_regex.merge(new_matches)
        new_online_matches.merge(new_matches)
      end
      resize_buffer!
      new_online_matches
    end

    def matches # Hash(Regexp, Set(OnlineMatch))
      @matches_per_regex
    end

    def matches_for(regex) # Set(OnlineMatch) | Nil
      @matches_per_regex[regex]
    end

    def resize_buffer!
      return unless @buffer.size > @window_size

      number_of_chars_at_front_of_buffer_that_should_roll_off = @buffer.size - @window_size

      @buffer = @buffer[-@window_size..-1]
      drop_matches_that_have_rolled_off(number_of_chars_at_front_of_buffer_that_should_roll_off)
    end

    def drop_matches_that_have_rolled_off(number_of_chars_at_front_of_buffer_that_rolled_off)
      @matches_per_regex.each do |regex, match_set|
        match_set.reject! {|online_match| online_match.offsets.first < number_of_chars_at_front_of_buffer_that_rolled_off }
      end
    end
  end

  # A {Regexp, MatchData} pair
  class OnlineMatch
    # Regexp  # MatchData  # Array(Int) -> [start, end]    # excludes the end offset
    attr_reader :regex
    attr_reader :match
    attr_reader :offsets # Regexp  # MatchData  # Array(Int) -> [start, end]    # excludes the end offset

    def initialize(regex, match)
      @regex, @match, @offsets = regex, match
      @offsets = match.offset(0)
    end

    def identity
      [@regex, @offsets, to_a]
    end

    def ==(other)
      identity == other.identity
    end

    def eql?(other)
      self == other
    end

    def hash
      identity.hash
    end

    def to_a
      @match.to_a
    end

    def to_h
      { @regex => to_a, :offsets => @offsets }
    end

    def captures
      @match.captures
    end

    def [](*args)
      @match.method(:[]).call(*args)
    end
  end
end
