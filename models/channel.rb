require 'active_record'
require_relative 'connection'
require_relative 'genre'

class Channel < ActiveRecord::Base
  belongs_to :user
  # info は JSON API、channel_info は ActiveRecord
  has_one :channel_info

  def status
    @status ||= peercast.getChannelStatus(gnu_id)
  end

  def info
    @info ||= peercast.getChannelInfo(gnu_id)
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
    peercast.getChannelConnections(gnu_id).map(&Connection.method(:new))
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
end
