require 'active_record'
require_relative 'connection'
require_relative 'genre'

class Channel < ActiveRecord::Base
  belongs_to :user
  # info は JSON API、channel_info は ActiveRecord
  has_one :channel_info

  def status
    set_status_info unless @status
    @status
  end

  def info
    set_status_info unless @info
    @info
  end

  def set_status_info
    dict = peercast.getChannels.find { |ch| ch['channelId'] == gnu_id }
    raise 'channel not found' unless dict
    @status = dict['status']
    @info = { 'info' => dict['info'], 'track' => dict['track'], 'yellowPages' => dict['yellowPages'] }
  end

  def playlist_url
    # WMV の場合
    case info['info']['contentType']
    when 'WMV'
      "http://#{PROXY_HOSTNAME}:8888/pls/#{gnu_id}.asx"
    when 'FLV'
      "http://#{PROXY_HOSTNAME}:8888/pls/#{gnu_id}.m3u"
    else
      ''
    end
  end

  def stream_url
    case info['info']['contentType']
    when 'WMV'
      "mmsh://#{PROXY_HOSTNAME}:8888/stream/#{gnu_id}.wmv"
    when 'FLV'
      "http://#{PROXY_HOSTNAME}:8888/stream/#{gnu_id}.flv"
    else
      ''
    end
  end

  def connections
    @connections ||= peercast.getChannelConnections(gnu_id).map(&Connection.method(:new))
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
  rescue Jimson::Client::Error
    false
  end

  def source_stream
    connections.find { |conn| conn.type == 'source' }
  end

  def destroy
    channel_info.terminated_at = Time.now
    channel_info.save!
    super
  end

end
