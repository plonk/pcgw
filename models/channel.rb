require 'active_record'
require_relative 'connection'
require_relative 'genre'

class Channel < ActiveRecord::Base
  belongs_to :user
  belongs_to :servent

  # info は JSON API、channel_info は ActiveRecord
  has_one :channel_info

  class ChannelNotFoundError < StandardError
  end

  def status
    set_status_info! unless @status
    @status
  end

  def info
    set_status_info! unless @info
    @info
  end

  # サーバーにチャンネルの状態を問い合わせて @status と @info にセットする。
  # また、last_active_at を更新する。
  def set_status_info!
    dict = servent.api.getChannels.find { |ch| ch['channelId'] == gnu_id }
    raise ChannelNotFoundError unless dict

    @status = dict['status']

    # 正常に受信中なら last_active_at を更新。
    if @status['status'] == "Receiving"
      source_connection = connections.find { |conn| conn.type == 'source' }
      if source_connection && source_connection.recvRateKbps >= 1.0
        self.last_active_at = Time.now
        save
      end
    end

    @info = dict.slice('info', 'track', 'yellowPages')
    nil
  end

  def playlist_url
    # WMV の場合
    case channel_info.stream_type
    when 'WMV'
      "http://#{servent.hostname}:#{servent.port}/pls/#{gnu_id}.asx"
    when 'FLV'
      "http://#{servent.hostname}:#{servent.port}/pls/#{gnu_id}.m3u"
    when 'MKV'
      "http://#{servent.hostname}:#{servent.port}/pls/#{gnu_id}.m3u"
    else
      ''
    end
  end

  def stream_url
    case channel_info.stream_type
    when 'WMV'
      "mmsh://#{servent.hostname}:#{servent.port}/stream/#{gnu_id}.wmv"
    when 'FLV'
      "http://#{servent.hostname}:#{servent.port}/stream/#{gnu_id}.flv"
    when 'MKV'
      "http://#{servent.hostname}:#{servent.port}/stream/#{gnu_id}.mkv"
    else
      ''
    end
  end

  def connections
    @connections ||= servent.api.getChannelConnections(gnu_id).map(&Connection.method(:new))
  end

  def listener_count_display
    genre = Genre.new(info['info']['genre'])

    if genre.hide_listener_count?
      '㊙'
    else
      status['totalDirects'].to_s
    end
  rescue ArgumentError
    return status['totalDirects'].to_s
  end

  def exist?
    status
    true
  rescue ChannelNotFoundError
    false
  end

  def source_connection
    connections.find { |conn| conn.type == 'source' }
  end

  def destroy
    info = self.channel_info

    # チャンネル情報からチャンネルへの参照をクリアする？
    # できてない気がする。
    self.channel_info = nil

    # 万一 ChannelInfo が無かった場合に消せなくならないようにしている。
    if info
      info.channel_id = nil
      info.terminated_at = Time.now
      info.save!
    end
    super
  end

  def ss_path
    "/ss/#{gnu_id}.jpg"
  end

end
