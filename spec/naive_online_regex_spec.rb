require_relative "./spec_helper"

include Kleene
include DSL

describe NaiveOnlineRegex do
  it "has an online matching interface" do
    a_star = /a*/
    noregex = NaiveOnlineRegex.new([a_star])

    input_string = "abaabaaa"

    noregex.reset

    noregex.ingest("ab").map(&:to_h).should eq([
      {a_star => ["a"]},
      {a_star => [""]},
      {a_star => [""]},
    ])
    noregex.matches.map{|k,v| [ [k, v.map(&:to_a)] ].to_h}.reduce(&:merge).should eq({
      a_star => [
       ["a"],
       [""],
       [""],
      ]
    })

    noregex.ingest("aa").map(&:to_h).should eq([
      {a_star=>["a"]},
      {a_star=>[""]},
      {a_star=>["aa"]},
      {a_star=>[""]},
    ])
    noregex.matches.map{|k,v| [ [k, v.map(&:to_a)] ].to_h}.reduce(&:merge).should eq({
      a_star => [
        ["a"],
        [""],
        [""],
        ["a"],
        [""],
        ["aa"],
        [""],
      ]
    })

    noregex.reset

    noregex.ingest("b").map(&:to_h).should eq([
      {/a*/=>[""]},
      {/a*/=>[""]},
    ])
    noregex.matches.map{|k,v| [ [k, v.map(&:to_a)] ].to_h}.reduce(&:merge).should eq({
      a_star => [
        [""], [""]
      ]
    })

    noregex.ingest("").map(&:to_h).should eq([ ])
    noregex.matches.map{|k,v| [ [k, v.map(&:to_a)] ].to_h}.reduce(&:merge).should eq({
      a_star => [
        [""], [""]
      ]
    })

    noregex.ingest("a").map(&:to_h).should eq([
      {/a*/=>[""]},
      {/a*/=>["a"]},
      {/a*/=>[""]},
    ])
    noregex.matches.map{|k,v| [ [k, v.map(&:to_a)] ].to_h}.reduce(&:merge).should eq({
      a_star => [
        [""], [""], [""], ["a"], [""]
      ]
    })

    noregex.ingest("aa").map(&:to_h).should eq([
      {/a*/=>[""]},
      {/a*/=>["aaa"]},
      {/a*/=>[""]},
    ])
    noregex.matches.map{|k,v| [ [k, v.map(&:to_a)] ].to_h}.reduce(&:merge).should eq({
      a_star => [
        [""], [""], [""], ["a"], [""], [""], ["aaa"], [""]
      ]
    })

  end
end
