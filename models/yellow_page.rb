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
                 'http://temp.orz.hm/yp/rule.html',
                 'http://temp.orz.hm/yp/',
                 'http://temp.orz.hm/yp/favicon.ico',
                 'pcp://temp.orz.hm/',
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
                 false]].map { |args| YellowPage.new(*args) }
      return @all
    end

  end

  attr_reader :name, :prefix, :terms, :top, :icon, :uri, :admin_only

  def initialize(name, prefix, terms, top, icon, uri, admin_only)
    @name       = name
    @prefix     = prefix
    @terms      = terms
    @top        = top
    @icon       = icon
    @uri        = uri
    @admin_only = admin_only
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
