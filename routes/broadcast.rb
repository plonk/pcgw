class BroadcastRequest
  def initialize(ch_info, yellow_pages)
    @ch_info = ch_info
    @yellow_pages = yellow_pages
  end

  def ypid
    yp ? yp.id : nil
  end

  def genre
    if !yp
      @ch_info.genre
    else
      yp.add_prefix(@ch_info.genre)
    end
  end

  def yp
    if @ch_info.yp.blank?
      nil
    else
      ret = @yellow_pages.find { |y| y.name == @ch_info.yp }
      fail "yellow page #{@ch_info.yp.inspect} not found" unless ret
      ret
    end
  end

  def to_h
    args = {
      yellowPageId:  ypid,
      info: {
        name:     @ch_info.channel,
        url:      @ch_info.url,
        bitrate:  '',
        mimeType: '',
        genre:    genre,
        desc:     @ch_info.desc,
        comment:  @ch_info.comment
      },
      track: {
        name:    '',
        creator: '',
        genre:   '',
        album:   '',
        url:     ''
      },
    }
    case @ch_info.stream_type
    when 'WMV'
      args.merge!(sourceUri:     source_uri_http(@ch_info.user),
                  sourceStream:  'http',
                  contentReader: 'ASF(WMV or WMA)')
    when 'FLV'
      args.merge!(sourceUri:     source_uri_rtmp(@ch_info.user),
                  sourceStream:  'RTMP Source',
                  contentReader: 'Flash Video (FLV)')
    else
      fail "unknown stream type #{@ch_info.stream_type}"
    end
    args
  end

  def source_uri_rtmp(user)
    port = 9000 + user.id
    "rtmp://#{PEERCAST_STATION_GLOBAL_HOSTNAME}:#{port}/live/livestream"
  end

  def source_uri_http(user)
    path = "#{9000 + user.id}"
    "http://#{WM_MIRROR_HOSTNAME}:5000/#{path}"
  end

end

class Pcgw < Sinatra::Base
  get '/create' do
    halt 503, h('現在チャンネルの作成はできません。') if NO_NEW_CHANNEL

    info = ChannelInfo.where(user: @user).order(created_at: :desc).limit(1)
    if info.empty?
      template = ChannelInfo.new(user: @user, channel: @user.name)
    else
      template, = info
    end
    erb :create, locals: { template: template }
  end

  def broadcast_check_params
    fail 'チャンネル名が入力されていません'     if params['channel'].blank?
    # fail '掲載YPが選択されていません'           if params['yp'].blank?
    fail 'ストリームタイプが選択されていません' if params['stream_type'].blank?
    # fail 'ジャンルが入力されていません'     if params['genre'].blank?
    # fail '詳細が入力されていません'         if params['desc'].blank?
    true
  end

  post '/broadcast' do
    halt 503, h('現在チャンネルの作成はできません。') if NO_NEW_CHANNEL

    begin
      broadcast_check_params

      props = params.slice('channel', 'desc', 'genre', 'yp', 'url', 'comment', 'stream_type')
      channel_info = ChannelInfo.new({ user: @user }.merge(props))

      request = BroadcastRequest.new(channel_info, @yellow_pages)
      chid = peercast.broadcastChannel(request.to_h)

      ch = @user.channels.build(gnu_id: chid)
      ch.save!
      channel_info.save!

      log.info("user #{@user.id} created channel #{ch.id}")

      redirect to("/channels/#{ch.id}")
    rescue StandardError => e
      # 必要なフィールドがなかった場合などフォームを再表示する
      @message = e.message
      erb :create, locals: { template: channel_info }
    end
  end

end
