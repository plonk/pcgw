# 掲載先ルートサーバー。
class YellowPage
  class << self
    def all
      @all ||= [['SP',
                 'sp',
                 'http://bayonet.ddo.jp/sp/notice.html',
                 'http://bayonet.ddo.jp/sp/',
                 nil,#'http://bayonet.ddo.jp/sp/favicon.ico',
                 'pcp://bayonet.ddo.jp:7146/',
                 false],
                ['TP',
                 'tp',
                 'http://160.16.61.57/yp/rule.html',
                 'http://160.16.61.57/yp/',
                 nil,#'http://160.16.61.57/yp/favicon.ico',
                 'pcp://160.16.61.57/',
                 false,
                 'ipv4',
                 false],
                ['p@',
                 '',
                 'https://p-at.net/terms',
                 'https://p-at.net/',
                 nil,
                 'pcp://root.p-at.net/',
                 false],
                ['Turf-Page(芝)',
                 'tp',
                 'http://takami98.sakura.ne.jp/peca-navi/turf-page/about.php',
                 'http://takami98.sakura.ne.jp/peca-navi/turf-page/',
                 nil,#'http://takami98.sakura.ne.jp/peca-navi/image/favicon.ico',
                 'pcp://takami98.luna.ddns.vc/',
                 false,
                 'ipv4',
                 false],
                ['平成YP',
                 '',
                 '',
                 'http://yp.pcgw.pgw.jp/',
                 'https://yp.pcgw.pgw.jp/favicon.ico',
                 'pcp://yp.pcgw.pgw.jp:7146/',
                 false,
                 'ipv4'],
                ['SecretYP',
                 '',
                 '',
                 'http://pcgw.pgw.jp:7144/public/',
                 nil,#'http://pcgw.pgw.jp:7144/assets/images/peercast-logo.png',
                 'pcp://pcgw.pgw.jp:7144/',
                 true,
                 'ipv4']].map { |args| YellowPage.new(*args) }
      return @all
    end

  end

  attr_reader :name, :prefix, :terms, :top, :icon, :uri, :admin_only, :network
  attr_reader :extant

  def initialize(name, prefix, terms, top, icon, uri, admin_only, network = 'ipv4', extant = true)
    @name       = name
    @prefix     = prefix
    @terms      = terms
    @top        = top
    @icon       = icon
    @uri        = uri
    @admin_only = admin_only
    @network    = network
    @extant     = extant
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
