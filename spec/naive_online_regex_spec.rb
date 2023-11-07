require_relative './spec_helper'

include Kleene
include DSL

describe NaiveOnlineRegex do
  it 'has an online matching interface' do
    a_star = /a*/
    noregex = NaiveOnlineRegex.new([a_star])

    input_string = 'abaabaaa'

    noregex.reset

    noregex.ingest('ab').map(&:to_h).should eq([
                                                 { /a*/ => ['a'], offsets: [0, 1] },
                                                 { /a*/ => [''], offsets: [1, 1] },
                                                 { /a*/ => [''], offsets: [2, 2] }
                                               ])
    noregex.matches.map {|k, v| [[k, v.map(&:to_h)]].to_h }.reduce(&:merge).should eq({
                                                                                        a_star => [
                                                                                          { /a*/ => ['a'], :offsets => [0, 1] },
                                                                                          { /a*/ => [''], :offsets => [1, 1] },
                                                                                          { /a*/ => [''], :offsets => [2, 2] }
                                                                                        ]
                                                                                      })

    noregex.ingest('aa').map(&:to_h).should eq([
                                                 { /a*/ => ['aa'], :offsets => [2, 4] },
                                                 { /a*/ => [''], :offsets => [4, 4] }
                                               ])
    noregex.matches.map {|k, v| [[k, v.map(&:to_h)]].to_h }.reduce(&:merge).should eq({
                                                                                        /a*/ => [
                                                                                          { /a*/ => ['a'], :offsets => [0, 1] },
                                                                                          { /a*/ => [''], :offsets => [1, 1] },
                                                                                          { /a*/ => [''], :offsets => [2, 2] },
                                                                                          { /a*/ => ['aa'], :offsets => [2, 4] },
                                                                                          { /a*/ => [''], :offsets => [4, 4] }
                                                                                        ]
                                                                                      })

    noregex.reset

    noregex.ingest('b').map(&:to_h).should eq([{ /a*/ => [''], :offsets => [0, 0] },
                                               { /a*/ => [''], :offsets => [1, 1] }])
    noregex.matches.map {|k, v| [[k, v.map(&:to_h)]].to_h }.reduce(&:merge).should eq({
                                                                                        /a*/ => [
                                                                                          { /a*/ => [''], :offsets => [0, 0] },
                                                                                          { /a*/ => [''], :offsets => [1, 1] }
                                                                                        ]
                                                                                      })

    noregex.ingest('').map(&:to_h).should eq([])
    noregex.matches.map do |k, v|
      [[k, v.map(&:to_h)]].to_h
    end.reduce(&:merge).should eq({ /a*/ => [{ /a*/ => [''], :offsets => [0, 0] }, { /a*/ => [''], :offsets => [1, 1] }] })

    noregex.ingest('a').map(&:to_h).should eq([{ /a*/ => ['a'], :offsets => [1, 2] },
                                               { /a*/ => [''], :offsets => [2, 2] }])
    noregex.matches.map {|k, v| [[k, v.map(&:to_h)]].to_h }.reduce(&:merge).should eq({
                                                                                        /a*/ => [
                                                                                          { /a*/ => [''], :offsets => [0, 0] },
                                                                                          { /a*/ => [''], :offsets => [1, 1] },
                                                                                          { /a*/ => ['a'], :offsets => [1, 2] },
                                                                                          { /a*/ => [''], :offsets => [2, 2] }
                                                                                        ]
                                                                                      })

    noregex.ingest('aa').map(&:to_h).should eq([{ /a*/ => ['aaa'], :offsets => [1, 4] },
                                                { /a*/ => [''], :offsets => [4, 4] }])
    noregex.matches.map {|k, v| [[k, v.map(&:to_h)]].to_h }.reduce(&:merge).should eq({
                                                                                        /a*/ => [
                                                                                          { /a*/ => [''], :offsets => [0, 0] },
                                                                                          { /a*/ => [''], :offsets => [1, 1] },
                                                                                          { /a*/ => ['a'], :offsets => [1, 2] },
                                                                                          { /a*/ => [''], :offsets => [2, 2] },
                                                                                          { /a*/ => ['aaa'], :offsets => [1, 4] },
                                                                                          { /a*/ => [''], :offsets => [4, 4] }
                                                                                        ]
                                                                                      })
  end

  it 'returns new matches' do
    noregex = NaiveOnlineRegex.new([/abc/, /def/], 10)

    noregex.reset

    noregex.ingest('ab').map(&:to_h).should eq([])
    noregex.matches.map {|k, v| [[k, v.map(&:to_h)]].to_h }.reduce(&:merge).should eq({ /abc/ => [], /def/ => [] })

    noregex.ingest('cd').map(&:to_h).should eq([{ /abc/ => ['abc'], :offsets => [0, 3] }])
    noregex.matches.map {|k, v| [[k, v.map(&:to_h)]].to_h }.reduce(&:merge).should eq({
                                                                                        /abc/ => [{ /abc/ => ['abc'], :offsets => [0, 3] }], /def/ => []
                                                                                      })

    noregex.ingest('e').map(&:to_h).should eq([])
    noregex.matches.map {|k, v| [[k, v.map(&:to_h)]].to_h }.reduce(&:merge).should eq({
                                                                                        /abc/ => [{ /abc/ => ['abc'], :offsets => [0, 3] }], /def/ => []
                                                                                      })

    noregex.ingest('').map(&:to_h).should eq([])
    noregex.matches.map {|k, v| [[k, v.map(&:to_h)]].to_h }.reduce(&:merge).should eq({
                                                                                        /abc/ => [{ /abc/ => ['abc'], :offsets => [0, 3] }], /def/ => []
                                                                                      })

    noregex.ingest('fghij').map(&:to_h).should eq([{ /def/ => ['def'], :offsets => [3, 6] }])
    noregex.matches.map {|k, v| [[k, v.map(&:to_h)]].to_h }.reduce(&:merge).should eq({
                                                                                        /abc/ => [{ /abc/ => ['abc'], :offsets => [0, 3] }],
                                                                                        /def/ => [{ /def/ => ['def'], :offsets => [3, 6] }]
                                                                                      })

    # this is the 11th char being ingested, which should make the first character drop off of the front of the buffer
    noregex.ingest('k').map(&:to_h).should eq([])
    noregex.matches.map {|k, v| [[k, v.map(&:to_h)]].to_h }.reduce(&:merge).should eq({
                                                                                        /abc/ => [],
                                                                                        /def/ => [{ /def/ => ['def'], :offsets => [3, 6] }]
                                                                                      })
  end

  it 'reports all new matches returned via #ingest but only remembers those that have occurred within the lookback window' do
    noregex = NaiveOnlineRegex.new([/abc/, /def/], 10)

    noregex.ingest('asdf;deflkjqwerpoiuabc').map(&:to_h).should eq([
                                                                     { /abc/ => ['abc'], :offsets => [19, 22] },
                                                                     { /def/ => ['def'], :offsets => [5, 8] }
                                                                   ])
    noregex.matches.map {|k, v| [[k, v.map(&:to_h)]].to_h }.reduce(&:merge).should eq({
                                                                                        /abc/ => [{ /abc/ => ['abc'], :offsets => [19, 22] }],
                                                                                        /def/ => []
                                                                                      })
  end
end
