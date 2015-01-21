class Pcgw < Sinatra::Base
  get '/create' do
    halt 503, h('現在チャンネルの作成はできません。') if NO_NEW_CHANNEL

    params.merge!(cookies.to_h.slice('channel', 'genre', 'comment', 'desc', 'yp', 'url', 'stream_type'))
    params['channel'] ||= @user.name
    erb :create
  end

  # YP の ID とジャンル文字列を params から決定する。
  def yellow_page_id_and_genre
    if params['yp'].blank?
      ypid = nil
      genre = params['genre']
    else
      ypid = params['yp'].to_i
      yp = peercast.getYellowPages.find { |y| y['yellowPageId'] == params['yp'].to_i }
      prefix = yp['name'].downcase
      if params['genre'] =~ /^#{prefix}/
        genre = params['genre']
      else
        genre = "#{prefix}#{params['genre']}"
      end
    end
    [ypid, genre]
  end

  def broadcast_check_params
    fail 'チャンネル名が入力されていません'     if params['channel'].blank?
    # fail '掲載YPが選択されていません'           if params['yp'].blank?
    fail 'ストリームタイプが選択されていません' if params['stream_type'].blank?
    # fail 'ジャンルが入力されていません'     if params['genre'].blank?
    # fail '詳細が入力されていません'         if params['desc'].blank?
    true
  end

  def create_broadcast_args(ypid, genre)
    args = {
      yellowPageId:  ypid,
      info: {
        name:     params['channel'],
        url:      params['url'],
        bitrate:  '',
        mimeType: '',
        genre:    genre,
        desc:     params['desc'],
        comment:  params['comment']
      },
      track: {
        name:    '',
        creator: '',
        genre:   '',
        album:   '',
        url:     ''
      },
    }
    if params['stream_type'] == 'WMV'
      args.merge!(sourceUri:     source_uri_http(@user),
                  sourceStream:  'http',
                  contentReader: 'ASF(WMV or WMA)')
    elsif params['stream_type'] == 'FLV'
      args.merge!(sourceUri:     source_uri_rtmp(@user),
                  sourceStream:  'RTMP Source',
                  contentReader: 'Flash Video (FLV)')
    else
      fail "unknown stream type #{params['stream_type']}"
    end
    args
  end

  post '/broadcast' do
    halt 503, h('現在チャンネルの作成はできません。') if NO_NEW_CHANNEL

    begin
      broadcast_check_params

      # 入力内容をクッキーに保存
      channel_fields = params.slice('channel', 'desc', 'genre', 'yp', 'url',
                                    'comment', 'stream_type')
      cookies.merge! channel_fields
      channel_info = ChannelInfo.new channel_fields.merge(user: @user)

      args = create_broadcast_args(*yellow_page_id_and_genre)
      gnuid = peercast.broadcastChannel(args)

      # チャンネルが残っているときに増えるのをふせぐ。
      # そもそも残っているべきではないが。
      unless ch = @user.channels.find_by(gnu_id: gnuid)
        ch = @user.channels.build(gnu_id: gnuid)
        ch.save!
      end
      channel_info.save!

      redirect to("/channels/#{ch.id}")
    rescue StandardError => e
      # 必要なフィールドがなかった場合などフォームを再表示する
      @message = e.message
      erb :create
    end
  end

end
