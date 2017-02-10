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
    set_status_info unless @status
    @status
  end

  def info
    set_status_info unless @info
    @info
  end

  def set_status_info
    dict = servent.api.getChannels.find { |ch| ch['channelId'] == gnu_id }
    raise ChannelNotFoundError unless dict
    @status = dict['status']
    if @status['status'] == "Receiving"
      self.last_active_at = Time.now
      save
    end
    @info = { 'info' => dict['info'], 'track' => dict['track'], 'yellowPages' => dict['yellowPages'] }
  end

  def inactive_for
    set_status_info unless @info
    if !last_active_at
      @status['uptime'].to_f
    else
      Time.now - last_active_at
    end
  end

  def playlist_url
    # WMV の場合
    case info['info']['contentType']
    when 'WMV'
      "http://#{servent.hostname}:#{servent.port}/pls/#{gnu_id}.asx"
    when 'FLV'
      "http://#{servent.hostname}:#{servent.port}/pls/#{gnu_id}.m3u"
    else
      ''
    end
  end

  def stream_url
    case info['info']['contentType']
    when 'WMV'
      "mmsh://#{servent.hostname}:#{servent.port}/stream/#{gnu_id}.wmv"
    when 'FLV'
      "http://#{servent.hostname}:#{servent.port}/stream/#{gnu_id}.flv"
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

  def source_stream
    connections.find { |conn| conn.type == 'source' }
  end

  def destroy
    info = self.channel_info

    # チャンネル情報からチャンネルへの参照をクリアする
    self.channel_info = nil

    # 万一 ChannelInfo が無かった場合に消せなくならないようにしている。
    if info
      info.terminated_at = Time.now
      info.save!
    end
    super
  end

end
