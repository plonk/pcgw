# PeerCast Station が持っているイエローページの情報
class YellowPage
  attr_reader :id, :name, :uri, :protocol
  attr_reader :channels # TODO: オブジェクト化したほうがいいかも

  def initialize(hash)
    @id = hash['yellowPageId']
    @name = hash['name']
    @uri = hash['uri']
    @protocol = hash['protocol']
    @channels = hash['channels']
  end

  def prefix
    @name.downcase
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
