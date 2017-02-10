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
                       'pcp://temp.orz.hm/'],
                     ]
      if ENV['PCGW_ENV'] == 'development'
        yellow_pages << ['TestP',
                         'tp',
                         '',
                         'http://localhost/',
                         'http://ie.pcgw.pgw.jp/favicon.ico',
                         'pcp://localhost:7146/']
      end
      return yellow_pages.map do |name, prefix, terms, top, icon, pcp|
        YellowPage.new('name'=>name, 'prefix'=>prefix, 'terms'=>terms, 'top'=>top, 'icon'=>icon, 'uri'=>pcp)
      end
    end

  end

  attr_reader :name
  attr_reader :prefix, :terms, :top, :icon, :uri

  def initialize(hash)
    @name = hash['name']
    @prefix = hash['prefix']
    @terms = hash['terms']
    @top = hash['top']
    @icon = hash['icon']
    @uri = hash['uri']
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
