module Kleene
  class NFATransition
    Epsilon = "\u0000"    # todo/hack: we use the null character as a sentinal character indicating epsilon transition

    attr_accessor :token # : Char
    attr_accessor :from # : State
    attr_accessor :to # : State

    def initialize(token, from_state, to_state)
      @token = token
      @from = from_state
      @to = to_state
    end

    def accept?(input)
      @token == input
    end

    def epsilon?
      token == Epsilon
    end
  end

  class NFA
    attr_accessor :alphabet # : Set(Char)
    attr_accessor :states # : Set(State)
    attr_accessor :start_state # : State
    attr_accessor :transitions # : Hash(State, Hash(Char, Set(NFATransition)))
    attr_accessor :current_states # : Set(State)
    attr_accessor :final_states # : Set(State)
    # @regex_pattern

    def initialize(start_state, alphabet = DEFAULT_ALPHABET, transitions = Hash.new, initial_states = nil)
      @start_state = start_state
      @transitions = transitions

      @alphabet = alphabet + all_transitions.map(&:token)

      @states = initial_states || reachable_states(start_state)
      @current_states = Set.new
      @final_states = Set.new

      update_final_states
      reset_current_states
    end

    def all_transitions() # : Array(NFATransition)
      transitions.flat_map {|state, char_transition_map| char_transition_map.values.flat_map(&:to_a) }
    end

    # def transitions_from(state) # : Set(NFATransition)
    #   @transitions[state]&.values&.reduce {|memo, set_of_transisions| memo | set_of_transisions} || Set.new
    # end
    def transitions_from(state_set) # : Set(NFATransition)
      case state_set
      when State
        @transitions[state_set]&.values&.reduce {|memo, set_of_transisions| memo | set_of_transisions} || Set.new
      when Set
        state_set.map {|state| transitions_from(state) }.reduce {|memo, state_set| memo | state_set }
      else
        raise "boom"
      end

    end

    def deep_clone
      old_states = @states.to_a
      new_states = old_states.map(&:dup)
      state_mapping = old_states.zip(new_states).to_h
      new_transitions = transitions.map {|state, char_transition_map|
        [
          state_mapping[state],
          char_transition_map.map {|char, set_of_transisions|
            [
              char,
              set_of_transisions.map {|transition| NFATransition.new(transition.token, state_mapping[transition.from], state_mapping[transition.to])}.to_set
            ]
          }.to_h
        ]
      }.to_h

      NFA.new(state_mapping[@start_state], @alphabet.clone, new_transitions, new_states.to_set).set_regex_pattern(regex_pattern)
    end

    def update_final_states
      @final_states = @states.select { |s| s.final? }.to_set
    end

    def reset_current_states
      @current_states = epsilon_closure(@start_state)
    end

    def error_states
      @states.select(&:error?).to_set
    end

    def add_state(new_state)
      @states << new_state
    end

    def add_states(states)
      @states.merge(states)
    end

    def remove_state(state)
      raise "Unable to remove state from NFA: at least one transition leads to or from the state." if all_transitions.any? {|transition| transition.from == state || transition.to == state }
      @states.delete(state)
    end

    def add_transition(token, from_state, to_state)
      # # make sure states EITHER have a single outbound epsilon transition OR non-epsilon outbound transitions; they can't have both
      # if token == NFATransition::Epsilon
      #   # make sure from_state doesn't have any outbound non-epsilon transitions
      #   raise "Error: Non-epsilon transitions are already present on #{from_state.to_s}! States may EITHER have a single outbound epsilon transision OR have outbound non-epsilon transitions, but not both." if transitions_from(from_state).any? {|t| !t.epsilon? }
      # else
      #   # make sure from_state doesn't have any outbound epsilon transition
      #   raise "Error: Epsilon transitions are already present on #{from_state.to_s}! States may EITHER have a single outbound epsilon transision OR have outbound non-epsilon transitions, but not both." if transitions_from(from_state).any?(&:epsilon?)
      # end

      @alphabet << token      # alphabet is a set, so there will be no duplications
      @states << from_state
      @states << to_state
      new_transition = NFATransition.new(token, from_state, to_state)

      char_transition_map = @transitions[from_state] ||= Hash.new
      set_of_transisions = char_transition_map[token] ||= Set.new
      set_of_transisions << new_transition

      new_transition
    end

    # Returns an array of matches found in the input string, each of which begins at the offset input_start_offset
    def matches_at_offset(input, input_start_offset)
      reset_current_states

      matches = []
      (input_start_offset...input.size).each do |offset|
        token = input[offset]
        handle_token!(token)
        if accept?
          matches << MatchRef.new(input, input_start_offset..offset)
        end
      end
      matches
    end

    # Returns an array of matches found anywhere in the input string
    def matches(input)
      (0...input.size).reduce([]) do |memo, offset|
        memo + matches_at_offset(input, offset)
      end
    end

    def match?(input) # : MatchRef?
      # puts "match?(\"#{input}\")"
      # puts self.to_s
      reset_current_states

      # puts @current_states.map(&:id)
      input.each_char.with_index do |char, index|
        # puts char
        handle_token!(char)
        # puts @current_states.map(&:id)
      end

      if accept?
        MatchRef.new(input, 0...input.size)
      end
    end

    # process another input token
    def handle_token!(input_token)
      @current_states = next_states(@current_states, input_token)
    end

    def accept?
      @current_states.any?(&:final?)
    end

    def next_states(state_set, input_token)
      # Retrieve a list of states in the epsilon closure of the given state set
      epsilon_reachable_states = epsilon_closure(state_set)
      # puts "epsilon_reachable_states = #{epsilon_reachable_states.map(&:id)}"

      # Build an array of outbound transitions from each state in the epsilon-closure
      # Filter the outbound transitions, selecting only those that accept the input we are given.
      outbound_transitions = epsilon_reachable_states.compact_map {|state| @transitions.dig(state, input_token) }.flat_map(&:to_a)
      # puts "outbound_transitions = #{outbound_transitions.inspect}"

      # Build an array of epsilon-closures of each transition's destination state.
      destination_state_epsilon_closures = outbound_transitions.map {|transition| epsilon_closure(transition.to) }

      # Union each of the epsilon-closures (each is a set) together to form a flat array of states in the epsilon-closure of all of our current states.
      next_states = destination_state_epsilon_closures.reduce {|combined_state_set, individual_state_set| combined_state_set.merge(individual_state_set) }

      next_states || Set.new
    end

    # Determine the epsilon closure of the given state set
    # That is, determine what states are reachable on an epsilon transition from the current state set (@current_states).
    # Returns a Set of State objects.
    def epsilon_closure(state_set) # : Set(State)
      state_set = state_set.is_a?(State) ? Set[state_set] : state_set
      visited_states = Set.new()
      unvisited_states = state_set
      while !unvisited_states.empty?
        epsilon_transitions = unvisited_states.compact_map {|state| @transitions.dig(state, NFATransition::Epsilon) }.flat_map(&:to_a)
        destination_states = epsilon_transitions.map(&:to).to_set
        visited_states.merge(unvisited_states)         # add the unvisited states to the visited_states
        unvisited_states = destination_states - visited_states
      end
      visited_states
    end

    # Returns a set of State objects which are reachable through any transition path from the NFA's start_state.
    def reachable_states(start_state)
      visited_states = Set.new()
      unvisited_states = Set[start_state]
      while !unvisited_states.empty?
        outbound_transitions = unvisited_states.flat_map {|state| @transitions[state]&.values&.flat_map(&:to_a) || Array.new }
        destination_states = outbound_transitions.map(&:to).to_set
        visited_states.merge(unvisited_states)         # add the unvisited states to the visited_states
        unvisited_states = destination_states - visited_states
      end
      visited_states
    end

    # This implements the subset construction algorithm presented on page 118 of the first edition of the dragon book.
    # I found a similar explanation at: http://web.cecs.pdx.edu/~harry/compilers/slides/LexicalPart3.pdf
    def to_dfa
      state_map = Hash.new            # this map contains (nfa_state_set => dfa_state) pairs
      dfa_transitions = Hash.new
      dfa_alphabet = @alphabet - Set[NFATransition::Epsilon]
      visited_state_sets = Set.new()
      nfa_start_state_set = epsilon_closure(@start_state)
      unvisited_state_sets = Set[nfa_start_state_set]

      dfa_start_state = State.new(nfa_start_state_set.any?(&:final?), nfa_start_state_set.any?(&:error?))
      state_map[nfa_start_state_set] = dfa_start_state
      until unvisited_state_sets.empty?
        # take one of the unvisited state sets
        state_set = unvisited_state_sets.first

        current_dfa_state = state_map[state_set]

        # Figure out the set of next-states for each token in the alphabet
        # Add each set of next-states to unvisited_state_sets
        dfa_alphabet.each do |token|
          next_nfa_state_set = next_states(state_set, token)
          unvisited_state_sets << next_nfa_state_set

          # this new DFA state, next_dfa_state, represents the next nfa state set, next_nfa_state_set
          next_dfa_state = state_map[next_nfa_state_set] ||= State.new(next_nfa_state_set.any?(&:final?), next_nfa_state_set.any?(&:error?))

          char_transition_map = dfa_transitions[current_dfa_state] ||= Hash.new
          char_transition_map[token] = DFATransition.new(token, current_dfa_state, next_dfa_state)
        end

        visited_state_sets << state_set
        unvisited_state_sets = unvisited_state_sets - visited_state_sets
      end

      # `state_map.invert` is sufficient to convert from a (nfa_state_set => dfa_state) mapping to a (dfa_state => nfa_state_set) mapping, because the mappings are strictly one-to-one.
      DFA.new(state_map[nfa_start_state_set], dfa_alphabet, dfa_transitions, state_map.invert, origin_nfa: self).set_regex_pattern(regex_pattern)
    end

    def graphviz
      retval = "digraph G { "
      all_transitions.each do |t|
        transition_label = t.epsilon? ? "ε" : t.token
        retval += "#{t.from.id} -> #{t.to.id} [label=\"#{transition_label}\"];"
      end
      @final_states.each do |s|
        retval += "#{s.id} [color=lightblue2, style=filled, shape=doublecircle];"
      end
      retval += " }"
      retval
    end

    def to_s(verbose = false)
      if verbose
        retval = states.map(&:to_s).join("\n")
        retval += "\n"
        all_transitions.each do |t|
          transition_label = t.epsilon? ? "epsilon" : t.token
          retval += "#{t.from.id} -> #{transition_label} -> #{t.to.id}\n"
        end
        retval
      else
        regex_pattern
      end
    end

    def set_regex_pattern(pattern)
      @regex_pattern = pattern
      self
    end

    def regex_pattern
      @regex_pattern || "<<empty>>"
    end
  end

end
