# IPアドレスを４〜５音節で日本語エンコードする。
module Nipponize
  ONSET_NUCLEUS = %w[ア イ ウ エ オ
                   カ キ ク ケ コ
                   サ シ ス セ ソ
                   タ チ ツ テ ト
                   ナ ニ ヌ ネ ノ
                   ハ ヒ フ ヘ ホ
                   マ ミ ム メ モ
                   ヤ ユ ヨ
                   ラ リ ル レ ロ
                   ワ
                   ガ ギ グ ゲ ゴ
                   ザ ジ ズ ゼ ゾ
                   ダ デ ド
                   バ ビ ブ ベ ボ
                   パ ピ プ ペ ポ
                   キャ キュ キョ
                   シャ シュ ショ
                   チャ チュ チョ
                   ニャ ニュ ニョ
                   ヒャ ヒュ ヒョ
                   ミャ ミュ ミョ
                   リャ リュ リョ
                   ギャ ギュ ギョ
                   ジャ ジュ ジョ
                   ビャ ビュ ビョ
                   ピャ ピュ ピョ
                   ファ フィ フェ フォ フュ
                   ウィ ウェ ウォ
                   ヴァ ヴィ ヴェ ヴォ
                   ツァ ツィ ツェ ツォ
                   チェ シェ ジェ
                   ティ ディ ドゥ トゥ]

  CODA = ['', 'ン', 'ッ']

  ALL_SYLLABLES = CODA.product(ONSET_NUCLEUS).map { |c, o| o + c }

  FINAL_SYLLABLES = ['', 'ン'].product(ONSET_NUCLEUS).map { |c, o| o + c } + ONSET_NUCLEUS.map { |c| c + c }

  combo = (ALL_SYLLABLES.cycle(2).to_a + FINAL_SYLLABLES).take(1024)
  SETS = [combo[0,256], combo[256,256], combo[512,256], combo[768,256]]

  
  # [Integer] → String
  def encode(addr)
    unless addr.size == 4 && addr.all? { |n| n.is_a? Integer }
      fail ArgumentError, 'addr must be array of Integer of length 4'
    end
    addr.map.with_index { |n, i| SETS[i][n] }.join
  end
  module_function :encode

  RSET = SETS.map { |set| set.map.with_index.to_a
                    .sort_by { |syllable, | syllable.size }
                    .reverse }
  # String → [Integer]
  def decode(str)
    addr = []

    4.times do |i|
      set = RSET[i]
      syl = nil
      j = nil
      set.each do |syllable, pos|
        syl = syllable
        if str.start_with?(syllable)
          j = pos
          break
        end
      end
      fail 'おかしい' if j.nil?

      addr << j
      str = str[syl.size..-1]
    end
    fail 'おかしい' unless str.empty?

    addr
  end
end

if __FILE__ == $0
  include Nipponize

  def demo(addr)
    word = encode(addr)
    puts "#{addr.join('.')} → #{word}"
    addr2 = decode(word)
    puts "#{word} → #{addr2.join('.')}"
    puts
    fail "おかしい" if addr != addr2
  end

  demo [127,0,0,1]
  demo [192,168,0,1]
  demo [0,0,0,0]

  5.times do
    addr = [rand(256), rand(256), rand(256), rand(256)]
    demo(addr)
  end
end
