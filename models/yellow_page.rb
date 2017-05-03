# PeerCast Station が持っているイエローページの情報
class YellowPage
  class << self
    def all
      yellow_pages = [['SP',
                       'sp',
                       'http://bayonet.ddo.jp/sp/notice.html',
                       'http://bayonet.ddo.jp/sp/',
                       'http://bayonet.ddo.jp/sp/favicon.ico',
                       'pcp://bayonet.ddo.jp:7146/',
                       false],
                      ['TP',
                       'tp',
                       'http://temp.orz.hm/yp/rule.html',
                       'http://temp.orz.hm/yp/',
                       'http://temp.orz.hm/yp/favicon.ico',
                       'pcp://temp.orz.hm/',
                       false],
                      ['TestP',
                       '',
                       '',
                       'http://yp.pcgw.pgw.jp/',
                       'http://ie.pcgw.pgw.jp/favicon.ico',
                       'pcp://yp.pcgw.pgw.jp:7146/',
                       true]]
      return yellow_pages.map do |name, prefix, terms, top, icon, pcp, admin_only|
        YellowPage.new('name'=>name, 'prefix'=>prefix, 'terms'=>terms, 'top'=>top, 'icon'=>icon, 'uri'=>pcp, 'admin_only'=>admin_only)
      end
    end

  end

  attr_reader :name
  attr_reader :prefix, :terms, :top, :icon, :uri, :admin_only

  def initialize(hash)
    @name       = hash['name']
    @prefix     = hash['prefix']
    @terms      = hash['terms']
    @top        = hash['top']
    @icon       = hash['icon']
    @uri        = hash['uri']
    @admin_only = hash['admin_only']
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
