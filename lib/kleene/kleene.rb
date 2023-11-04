# this is a port and extension of https://github.com/davidkellis/kleene/

require_relative "./dsl"
require_relative "./nfa"
require_relative "./dfa"

module Kleene
  # The default alphabet consists of the following:
  # Set{' ', '!', '"', '#', '$', '%', '&', '\'', '(', ')', '*', '+', ',', '-', '.', '/',
  #     '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
  #     ':', ';', '<', '=', '>', '?', '@',
  #     'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
  #     'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  #     '[', '\\', ']', '^', '_', '`',
  #     'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
  #     'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
  #     '{', '|', '}', '~', "\n", "\t"}
  DEFAULT_ALPHABET = ((' '..'~').to_a + "\n\t".chars).to_set

  class State
    @@next_id = 0

    def self.next_id
      @@next_id += 1
    end

    def self.new_error_state(final = false)
      State.new(final, true)
    end


    attr_reader :id # : Int32
    attr_accessor :final # : Bool
    attr_accessor :error # : Bool

    def initialize(final = false, error = false, id = nil)
      @final = final
      @error = error
      @id = id || State.next_id
    end

    # is this an error state?
    def error?
      @error
    end

    # is this a final state?
    def final?
      @final
    end

    def dup
      State.new(@final, @error, nil)
    end

    def to_s
      "State{id: #{id}, final: #{final}, error: #{error}}"
    end
  end

  class MatchRef
    attr_accessor :string # : String
    attr_accessor :range # : Range(Int32, Int32)

    def initialize(original_string, match_range)
      @string = original_string
      @range = match_range
    end

    def text
      @string[@range]
    end

    def to_s
      text
    end

    def ==(other)
      @string == other.string &&
      @range == other.range
    end

    def eql?(other)
      self == other
    end
  end

end
