# ジャンル文字列に追加された YP4G コマンドを解釈する
class Genre
  attr_reader :namespace, :minimum_bandwidth, :proper

  def initialize(genre_string)
    @genre_string = genre_string

    if /^.p(?:([a-zA-Z0-9]*):)?(\??)(@*)(.*)$/ =~ genre_string
      @namespace = $1
      @hide_listener_count = ($2 == '?')
      @minimum_bandwidth = $3
      @proper = $4
    else
      fail ArgumentError, 'format error'
    end
  end

  def to_s
    @genre_string
  end

  def hide_listener_count?
    @hide_listener_count
  end
end
