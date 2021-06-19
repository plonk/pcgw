# 掲載先ルートサーバー。
class YellowPage
  class << self
    def all
      @all ||= [['SP',
                 'sp',
                 'http://bayonet.ddo.jp/sp/notice.html',
                 'http://bayonet.ddo.jp/sp/',
                 'http://bayonet.ddo.jp/sp/favicon.ico',
                 'pcp://bayonet.ddo.jp:7146/',
                 false],
                ['TP',
                 'tp',
                 'http://160.16.61.57/yp/rule.html',
                 'http://160.16.61.57/yp/',
                 'http://160.16.61.57/yp/favicon.ico',
                 'pcp://160.16.61.57/',
                 false],
                ['Turf-Page(芝)',
                 'tp',
                 'http://takami98.sakura.ne.jp/peca-navi/turf-page/about.php',
                 'http://takami98.sakura.ne.jp/peca-navi/turf-page/',
                 'http://takami98.sakura.ne.jp/peca-navi/image/favicon.ico',
                 'pcp://takami98.luna.ddns.vc/',
                 false],
                ['平成YP',
                 '',
                 'http://yp.pcgw.pgw.jp/kiyaku.html',
                 'http://yp.pcgw.pgw.jp/',
                 'http://yp.pcgw.pgw.jp/favicon.ico',
                 'pcp://yp.pcgw.pgw.jp:7146/',
                 false,
                 'ipv6']].map { |args| YellowPage.new(*args) }
      return @all
    end

  end

  attr_reader :name, :prefix, :terms, :top, :icon, :uri, :admin_only, :network

  def initialize(name, prefix, terms, top, icon, uri, admin_only, network = 'ipv4')
    @name       = name
    @prefix     = prefix
    @terms      = terms
    @top        = top
    @icon       = icon
    @uri        = uri
    @admin_only = admin_only
    @network    = network
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
