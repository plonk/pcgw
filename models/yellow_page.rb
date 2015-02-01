# PeerCast Station が持っているイエローページの情報
class YellowPage
  class << self
    def all
      # 登録されていなかったら登録する
      json_ary = peercast.getYellowPages
      yellow_pages = [['SP',
                       'sp',
                       'http://bayonet.ddo.jp/sp/notice.html',
                       'http://bayonet.ddo.jp/sp/',
                       'http://bayonet.ddo.jp/sp/favicon.ico',
                       'pcp://bayonet.ddo.jp:7146/'],
                      ['TP',
                       'tp',
                       'http://temp.orz.hm/yp/rule.html',
                       'pcp://temp.orz.hm/',
                       'http://temp.orz.hm/yp/favicon.ico',
                       'pcp://temp.orz.hm/']]
      yellow_pages.each do |name, prefix, terms, top, icon, pcp|
        unless json_ary.find { |y| y['name'] == name }
          peercast.addYellowPage('pcp', name, pcp)
        end
      end

      # オブジェクトの作成
      json_ary = peercast.getYellowPages # 再読み込み
      return yellow_pages.map do |name, prefix, terms, top, icon, pcp|
        hash = json_ary.find { |y| y['name'] == name }
        hash.merge!('prefix'=>prefix, 'terms'=>terms, 'top'=>top, 'icon'=>icon)
        YellowPage.new(hash)
      end
    end

  end

  attr_reader :id, :name, :uri, :protocol
  attr_reader :channels # TODO: オブジェクト化したほうがいいかも
  attr_reader :prefix, :terms, :top, :icon

  def initialize(hash)
    @id = hash['yellowPageId']
    @name = hash['name']
    @uri = hash['uri']
    @protocol = hash['protocol']
    @channels = hash['channels']

    @prefix = hash['prefix']
    @terms = hash['terms']
    @top = hash['top']
    @icon = hash['icon']
  end

 def prefixed?(genre)
    !!(genre =~ /^#{prefix}/)
  end

  # チャンネル掲載に必要なジャンル文字列のプリフィクスを追加する
  def add_prefix(genre)
    if prefixed?(genre)
      genre
    else
      "#{prefix}#{genre}"
    end
  end

end
