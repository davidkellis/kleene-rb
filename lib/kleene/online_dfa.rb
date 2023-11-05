require "stringio"
require_relative "./kleene"

module Kleene
  class MachineTuple
    attr_accessor :nfa # : NFA
    attr_accessor :nfa_with_dead_err # : NFA
    attr_accessor :dfa # : DFA

    def initialize(nfa, nfa_with_dead_err, dfa)
      @nfa, @nfa_with_dead_err, @dfa = nfa, nfa_with_dead_err, dfa
    end
  end

  class OnlineDFA
    include DSL

    # @original_nfas : Array(NFA)
    attr_reader :nfas_with_err_state # : Array(NFA)
    attr_accessor :dead_end_nfa_state_to_dead_end_nfa # : Hash(State, NFA)
    attr_accessor :composite_nfa # : NFA
    attr_accessor :composite_dfa # : DFA

    attr_accessor :machines_by_index # : Hash(Int32, MachineTuple)
    attr_accessor :nfa_to_index # : Hash(NFA, Int32)
    attr_accessor :nfa_with_dead_err_to_index # : Hash(NFA, Int32)
    attr_accessor :dfa_to_index # : Hash(DFA, Int32)

    def initialize(nfas)
      composite_alphabet = nfas.reduce(Set.new) {|memo, nfa| memo | nfa.alphabet }

      @original_nfas = nfas
      @nfas_with_err_state = nfas.map {|nfa| with_err_dead_end(nfa, composite_alphabet) }     # copy NFAs and add dead-end error states to each of them
      dfas = @original_nfas.map(&:to_dfa)

      @nfa_to_index = @original_nfas.map.with_index {|nfa, index| [nfa, index] }.to_h
      @nfa_with_dead_err_to_index = @nfas_with_err_state.map.with_index {|nfa, index| [nfa, index] }.to_h
      @dfa_to_index = dfas.map.with_index {|dfa, index| [dfa, index] }.to_h
      @machines_by_index = @original_nfas.zip(nfas_with_err_state, dfas).map.with_index {|tuple, index| nfa, nfa_with_dead_err, dfa = tuple; [index, MachineTuple.new(nfa, nfa_with_dead_err, dfa)] }.to_h

      # build a mapping of (state -> nfa) pairs that capture which nfa owns each state
      @dead_end_nfa_state_to_dead_end_nfa = Hash.new
      @nfas_with_err_state.each do |nfa_with_dead_err|
        nfa_with_dead_err.states.each do |state|
          @dead_end_nfa_state_to_dead_end_nfa[state] = nfa_with_dead_err
        end
      end

      # create a composite NFA as the union of all the NFAs with epsilon transitions from every NFA state back to the union NFA's start state
      @composite_nfa = create_composite_nfa(@nfas_with_err_state)
      @composite_dfa = @composite_nfa.to_dfa

      reset
    end

    def machines_from_nfa(nfa) # : MachineTuple
      machines_by_index[nfa_to_index[nfa]]
    end

    def machines_from_nfa_with_dead_err(nfa_with_dead_err) # : MachineTuple
      machines_by_index[nfa_with_dead_err_to_index[nfa_with_dead_err]]
    end

    def machines_from_dfa(dfa) # : MachineTuple
      machines_by_index[dfa_to_index[dfa]]
    end

    # create a composite NFA as the union of all the NFAs with epsilon transitions from every NFA state back to the union NFA's start state
    def create_composite_nfa(nfas)
      nfa = union!(nfas)

      # add epsilon transitions from all the states except the start state back to the start state
      nfa.states.each do |state|
        if state != nfa.start_state
          nfa.add_transition(NFATransition::Epsilon, state, nfa.start_state)
        end
      end

      nfa.update_final_states

      nfa
    end

    def reset # : OnlineMatchTracker
      @active_composite_dfa = @composite_dfa.deep_clone
      @active_candidate_dfas = []
      @match_tracker = setup_callbacks(@active_composite_dfa)
      @buffer = ""
    end

    # #ingest(input) is the online-style matching interface
    def ingest(input, debug = false) # : Hash(NFA, Array(MatchRef))
      mt = @match_tracker

      start_index_of_input_fragment_in_buffer = @buffer.length

      input.each_char.with_index do |char, index|
        @active_composite_dfa.handle_token!(char, start_index_of_input_fragment_in_buffer + index)
      end

      @buffer << input

      start_index_to_nfas_that_may_match = mt.invert_candidate_match_start_positions

      mt.empty_matches.each do |nfa_with_dead_err, indices|
        original_nfa = machines_from_nfa_with_dead_err(nfa_with_dead_err).nfa
        indices.select {|index| index >= start_index_of_input_fragment_in_buffer }.each do |index|
          mt.add_match(original_nfa, MatchRef.new(@buffer, index...index))
        end
      end

      input.each_char.with_index do |char, index|
        index_in_buffer = start_index_of_input_fragment_in_buffer + index

        @active_candidate_dfas.reject! do |active_dfa_tuple|
          dfa_clone, original_nfa, start_of_match_index = active_dfa_tuple

          dfa_clone.handle_token!(char, index_in_buffer)
          mt.add_match(original_nfa, MatchRef.new(@buffer, start_of_match_index..index_in_buffer)) if dfa_clone.accept?

          dfa_clone.error?
        end

        if nfas_with_dead_err = start_index_to_nfas_that_may_match[index_in_buffer]
          nfas_with_dead_err.each do |nfa_with_dead_err|
            machines = machines_from_nfa_with_dead_err(nfa_with_dead_err)
            original_nfa = machines.nfa
            dfa = machines.dfa
            dfa_clone = dfa.shallow_clone

            dfa_clone.handle_token!(char, index_in_buffer)
            mt.add_match(original_nfa, MatchRef.new(@buffer, index_in_buffer..index_in_buffer)) if dfa_clone.accept?

            @active_candidate_dfas << [dfa_clone, original_nfa, index_in_buffer] unless dfa_clone.error?
          end
        end
      end

      matches
    end

    def matches
      @match_tracker.matches
    end

    def setup_callbacks(dfa)
      match_tracker = OnlineMatchTracker.new

      # 1. identify DFA states that correspond to successful match of first character of the NFAs
      epsilon_closure_of_nfa_start_state = composite_nfa.epsilon_closure(composite_nfa.start_state)
      nfa_states_that_correspond_to_successful_match_of_first_character_of_component_nfa = composite_nfa.transitions_from(epsilon_closure_of_nfa_start_state).
                                                                                                         reject {|transition| transition.epsilon? || transition.to.error? }.
                                                                                                         map(&:to).to_set
      dfa_states_that_correspond_to_successful_match_of_first_character_of_component_nfa = nfa_states_that_correspond_to_successful_match_of_first_character_of_component_nfa.
                                                                                              compact_map {|nfa_state| dfa.nfa_state_to_dfa_state_sets[nfa_state] }.
                                                                                              reduce(Set.new) {|memo, state_set| memo | state_set }
      dfa_state_to_dead_end_nfas_that_have_matched_their_first_character = Hash.new
      dfa_states_that_correspond_to_successful_match_of_first_character_of_component_nfa.each do |dfa_state|
        dfa_state_to_dead_end_nfas_that_have_matched_their_first_character[dfa_state] = dfa.dfa_state_to_nfa_state_sets[dfa_state].
                                                                                            select {|nfa_state| nfa_states_that_correspond_to_successful_match_of_first_character_of_component_nfa.includes?(nfa_state) }.
                                                                                            compact_map do |nfa_state|
          dead_end_nfa_state_to_dead_end_nfa[nfa_state] unless nfa_state == composite_nfa.start_state    # composite_nfa.start_state is not referenced in the dead_end_nfa_state_to_dead_end_nfa map
        end.to_set
      end

      # 2. identify DFA states that correspond to final states in the NFAs
      nfa_final_states = @nfas_with_err_state.map(&:final_states).reduce(Set.new) {|memo, state_set| memo | state_set }
      dfa_states_that_correspond_to_nfa_final_states = nfa_final_states.compact_map {|nfa_state| dfa.nfa_state_to_dfa_state_sets[nfa_state] }.
                                                                        reduce(Set.new) {|memo, state_set| memo | state_set }
      dead_end_nfas_that_have_transitioned_to_final_state = Hash.new
      dfa_states_that_correspond_to_nfa_final_states.each do |dfa_state|
        dead_end_nfas_that_have_transitioned_to_final_state[dfa_state] = dfa.dfa_state_to_nfa_state_sets[dfa_state].
                                                                             select {|nfa_state| nfa_final_states.includes?(nfa_state) }.
                                                                             compact_map do |nfa_state|
          dead_end_nfa_state_to_dead_end_nfa[nfa_state] unless nfa_state == composite_nfa.start_state    # composite_nfa.start_state is not referenced in the dead_end_nfa_state_to_dead_end_nfa map
        end.to_set
      end

      # 3. Identify DFA states that correspond to successful match without even having seen any characters.
      #    These are cases where the NFA's start state is a final state or can reach a final state by following only epsilon transitions.
      nfa_final_states_that_are_epsilon_reachable_from_nfa_start_state = epsilon_closure_of_nfa_start_state.select(&:final?).to_set
      dfa_states_that_represent_both_start_states_and_final_states = nfa_final_states_that_are_epsilon_reachable_from_nfa_start_state.
                                                                        compact_map {|nfa_state| dfa.nfa_state_to_dfa_state_sets[nfa_state] }.
                                                                        reduce(Set.new) {|memo, state_set| memo | state_set }
      dfa_state_to_dead_end_nfas_that_have_matched_before_handling_any_characters = Hash.new
      dfa_states_that_represent_both_start_states_and_final_states.each do |dfa_state|
        dfa_state_to_dead_end_nfas_that_have_matched_before_handling_any_characters[dfa_state] = dfa.dfa_state_to_nfa_state_sets[dfa_state].
                                                                                                     select {|nfa_state| nfa_final_states_that_are_epsilon_reachable_from_nfa_start_state.includes?(nfa_state) }.
                                                                                                     compact_map do |nfa_state|
          dead_end_nfa_state_to_dead_end_nfa[nfa_state] unless nfa_state == composite_nfa.start_state    # composite_nfa.start_state is not referenced in the dead_end_nfa_state_to_dead_end_nfa map
        end.to_set
      end

      # set up call transition call backs, since the callbacks may only be defined once per state and transition
      # For (1):
      #    Set up transition callbacks to push the index position of the start of a match of each NFA that has begun
      #    to be matched on the transition to one of the states in (1)
      # For (2):
      #    set up transition callbacks to push the index position of the end of a successful match onto the list
      #    of successful matches for the NFA that matched
      # For (3):
      #    set up transision callbacks to capture successful empty matches
      destination_dfa_states_for_callbacks = dfa_states_that_correspond_to_successful_match_of_first_character_of_component_nfa | dfa_states_that_correspond_to_nfa_final_states
      destination_dfa_states_for_callbacks.each do |dfa_state|
        dfa.on_transition_to(dfa_state) do |transition, token, token_index|
          destination_dfa_state = transition.to

          should_track_empty_match = dfa_states_that_represent_both_start_states_and_final_states.includes?(destination_dfa_state)
          should_track_start_of_candidate_match = should_track_empty_match || dfa_states_that_correspond_to_successful_match_of_first_character_of_component_nfa.includes?(destination_dfa_state)
          should_track_end_of_match = dfa_states_that_correspond_to_nfa_final_states.includes?(destination_dfa_state)

          if should_track_empty_match
            dfa_state_to_dead_end_nfas_that_have_matched_before_handling_any_characters[destination_dfa_state].each do |nfa_with_dead_end|
              match_tracker.add_empty_match(nfa_with_dead_end, token_index)
            end
          end

          if should_track_start_of_candidate_match
            nfas_that_matched_first_character = dfa_state_to_dead_end_nfas_that_have_matched_their_first_character[destination_dfa_state] || Set.new
            nfas_that_matched_empty_match = dfa_state_to_dead_end_nfas_that_have_matched_before_handling_any_characters[destination_dfa_state] || Set.new
            dead_end_nfas_that_are_starting_to_match = nfas_that_matched_first_character | nfas_that_matched_empty_match
            dead_end_nfas_that_are_starting_to_match.each do |nfa_with_dead_end|
              match_tracker.add_start_of_candidate_match(nfa_with_dead_end, token_index)
            end
          end

          if should_track_end_of_match
            dead_end_nfas_that_have_transitioned_to_final_state[destination_dfa_state].each do |nfa_with_dead_end|
              match_tracker.add_end_of_match(nfa_with_dead_end, token_index)
            end
          end
        end
      end

      match_tracker
    end
  end

  class OnlineMatchTracker
    # The NFA keys in the following two structures are not the original NFAs supplied to the MultiMatchDFA.
    # They are the original NFAs that have been augmented with a dead end error state, so the keys are objects that
    # are the internal state of a MultiMatchDFA
    attr_accessor :candidate_match_start_positions # : Hash(NFA, Array(Int32))     # NFA -> Array(IndexPositionOfStartOfMatch)
    #  The end positions are indices at which, after handling the character, the DFA was observed to be in a match/accept state;
    #  however, the interpretation is ambiguous, because the accepting state may be as a result of (1) transitioning to an error state that is also marked final/accepting,
    #  OR it may be as a result of transitioning to (2) a non-error final state.
    #  In the case of (1), the match may be an empty match, where after transitioning to an error state, the DFA is in a state that
    #  is equivalent to the error state and start state and final state (e.g. as in an optional or kleene star DFA),
    #  while in the case of (2), the match may be a "normal" match.
    #  The ambiguity is problematic because it isn't clear whether the index position of the match is end inclusive end of a match
    #  or the beginning of an empty match.
    #  This ambiguity is all due to the construction of the composite DFA in the MultiMatchDFA - the dead end error states are epsilon-transitioned
    #  to the composite DFA's start state.
    attr_accessor :match_end_positions # : Hash(NFA, Array(Int32))                 # NFA -> Array(IndexPositionOfEndOfMatch)
    attr_accessor :empty_matches # : Hash(NFA, Array(Int32))                       # NFA -> Array(IndexPositionOfEmptyMatch)

    # The NFA keys in the following structure are the original NFAs supplied to the MultiMatchDFA.
    # This is in contrast to the augmented NFAs that are used as keys in the candidate_match_start_positions and
    # match_end_positions structures, documented above ^^^.
    attr_accessor :matches # : Hash(NFA, Array(MatchRef))  # NFA -> Array(MatchRef)

    def initialize
      reset
    end

    def reset
      @candidate_match_start_positions = Hash.new
      @match_end_positions = Hash.new
      @empty_matches = Hash.new
      @matches = Hash.new
    end

    def start_positions(nfa)
      candidate_match_start_positions[nfa] ||= Array.new
    end

    def end_positions(nfa)
      match_end_positions[nfa] ||= Array.new
    end

    def empty_match_positions(nfa)
      empty_matches[nfa] ||= Array.new
    end

    def matches_for(nfa)
      matches[nfa] ||= Array.new
    end

    def add_start_of_candidate_match(nfa_with_dead_end, token_index)
      # puts "add_start_of_candidate_match(#{nfa.object_id}, #{token_index})"
      positions = start_positions(nfa_with_dead_end)
      positions << token_index
    end

    #  the end positions are inclusive of the index of the last character matched, so empty matches are not accounted for in the match_end_positions array
    def add_end_of_match(nfa_with_dead_end, token_index)
      # puts "add_end_of_match(#{nfa.object_id}, #{token_index})"
      positions = end_positions(nfa_with_dead_end)
      positions << token_index
    end

    def add_empty_match(nfa_with_dead_end, token_index)
      positions = empty_match_positions(nfa_with_dead_end)
      positions << token_index
    end

    def invert_candidate_match_start_positions # : Hash(Int32, Array(NFA))
      index_to_nfas = Hash.new
      candidate_match_start_positions.each do |nfa_with_dead_end, indices|
        indices.each do |index|
          nfas = index_to_nfas[index] ||= Array.new
          nfas << nfa_with_dead_end
        end
      end
      index_to_nfas
    end

    def add_match(nfa, match)
      matches = matches_for(nfa)
      matches << match
    end
  end
end
