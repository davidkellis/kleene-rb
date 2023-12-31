# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext'
require 'regexp_parser'
require_relative 'kleene/version'
require_relative 'kleene/patches'
require_relative 'kleene/kleene'
require_relative 'kleene/dsl'
require_relative 'kleene/nfa'
require_relative 'kleene/dfa'
require_relative 'kleene/multi_match_dfa'
require_relative 'kleene/online_dfa'
require_relative 'kleene/naive_online_regex'
require_relative 'kleene/parser'

module Kleene
  class Error < StandardError; end
  # Your code goes here...
end
