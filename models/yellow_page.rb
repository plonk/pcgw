# PeerCast Station が持っているイエローページの情報
class YellowPage
  class << self
    def all
      yellow_pages = [['SP',
                       'sp',
                       'http://bayonet.ddo.jp/sp/notice.html',
                       'http://bayonet.ddo.jp/sp/',
                       'http://bayonet.ddo.jp/sp/favicon.ico',
                       'pcp://bayonet.ddo.jp:7146/'],
                      ['TP',
                       'tp',
                       'http://temp.orz.hm/yp/rule.html',
                       'http://temp.orz.hm/yp/',
                       'http://temp.orz.hm/yp/favicon.ico',
                       'pcp://temp.orz.hm/']]
      return yellow_pages.map do |name, prefix, terms, top, icon, pcp|
        YellowPage.new('name'=>name, 'prefix'=>prefix, 'terms'=>terms, 'top'=>top, 'icon'=>icon)
      end
    end

  end

  attr_reader :name
  attr_reader :prefix, :terms, :top, :icon

  def initialize(hash)
    @name = hash['name']
    @prefix = hash['prefix']
    @terms = hash['terms']
    @top = hash['top']
    @icon = hash['icon']
  end

  def set_extras
    hash = peercast.getYellowPages.find { |yp| yp['name'] == @name }
    raise "yellow page #{@name} not found on peercast station" unless hash

    @id = hash['yellowPageId']
    @uri = hash['uri']
    @protocol = hash['protocol']
    @channels = hash['channels']
  end

  def id
    set_extras; @id
  end

  def uri
    set_extras; @uri
  end

  def protocol
    set_extras; @protocol
  end

  # TODO: オブジェクト化したほうがいいかも
  def channels
    set_extras; @channels
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
