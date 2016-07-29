# ジャンル文字列に追加された YP4G コマンドを解釈する
class Genre
  attr_reader :namespace, :minimum_bandwidth, :proper, :no_statistics

  def initialize(genre_string)
    @genre_string = genre_string

    if /^.p(?:([a-zA-Z0-9]*):)?(\??)(@*)(\+?)(.*)$/ =~ genre_string
      @namespace = $1
      @hide_listener_count = ($2 == '?')
      @minimum_bandwidth = $3
      @no_statistics = ($4 == '+')
      @proper = $5
    else
      @namespace = ''
      @hide_listener_count = false
      @minimum_bandwidth = ''
      @no_statistics = false
      @proper = genre_string
    end
  end

  def to_s
    @genre_string
  end

  def hide_listener_count?
    @hide_listener_count
  end
end
