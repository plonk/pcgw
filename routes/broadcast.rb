require 'lockfile'

# チャンネル作成要求を表わすクラス。
class BroadcastRequest
  attr_reader :info

  def initialize(servent, ch_info, yellow_pages, client_ip)
    @servent = servent
    @info = ch_info
    @yellow_pages = yellow_pages
    @client_ip = client_ip
  end

  def ypid
    if yp
      pecastYP = @servent.api.getYellowPages.find { |y| y['name'] == yp.name }
      unless pecastYP
        raise "YP not found. servent #{@servent.name} is not properly set up."
      end
      pecastYP['yellowPageId']
    else
      nil
    end
  end

  def genre
    if !yp
      @info.genre
    else
      yp.add_prefix(@info.genre)
    end
  end

  def yp
    if @info.yp.blank?
      nil
    else
      ret = @yellow_pages.find { |y| y.name == @info.yp }
      fail "yellow page #{@info.yp.inspect} not found" unless ret
      ret
    end
  end

  # broadcastChannel RPC への引数をビルドする。
  def to_h
    args = {
      yellowPageId:  ypid,
      info: {
        name:     @info.channel,
        url:      @info.url,
        bitrate:  '',
        mimeType: '',
        genre:    genre,
        desc:     @info.desc,
        comment:  @info.comment
      },
      track: {
        name:    '',
        creator: "#{@client_ip} via Peercast Gateway",
        genre:   '',
        album:   '',
        url:     ''
      },
    }
    case @info.stream_type
    when 'WMV'
      args.merge!(sourceUri:     source_uri,
                  sourceStream:  'http',
                  contentReader: 'ASF(WMV or WMA)')
    when 'FLV'
      args.merge!(sourceUri:     source_uri,
                  sourceStream:  'RTMP Source',
                  contentReader: 'Flash Video (FLV)')
    else
      fail "unknown stream type #{@info.stream_type}"
    end
    args
  end

  def source_uri
    case @info.stream_type
    when 'WMV'
      source_uri_http(@info.user)
    when 'FLV'
      source_uri_rtmp(@info.user)
    else
      fail
    end
  end

  private

  def source_uri_rtmp(user)
    port = 9000 + user.id
    "rtmp://#{@servent.hostname}:#{port}/live/livestream"
  end

  def source_uri_http(user)
    path = "#{9000 + user.id}"
    "http://#{WM_MIRROR_HOSTNAME}:5000/#{path}"
  end

end

class Pcgw < Sinatra::Base
  get '/create' do
    halt 503, h('現在チャンネルの作成はできません。') if NO_NEW_CHANNEL || Servent.enabled.empty?

    if params['template'].blank?
      info = ChannelInfo.where(user: @user).order(created_at: :desc).limit(1)
      if info.empty?
        template = ChannelInfo.new(user: @user, channel: @user.name)
      else
        template, = info
      end
    else
      begin
        # 他のユーザーの ChannelInfo はテンプレートにしない。
        template = ChannelInfo.where(user: @user).find(params['template'])
      rescue ActiveRecord::RecordNotFound
        halt 400, h('テンプレートが見付かりません。')
      end
    end

    erb :create, locals: { template: template, servents: Servent.enabled }
  end

  def broadcast_check_params!
    fail 'チャンネル名が入力されていません'     if params['channel'].blank?
    fail 'ストリームタイプが選択されていません' if params['stream_type'].blank?
  end

  def ascertain_new!(peercast, req)
    if peercast.getChannels.any? { |ch|
        ch['info']['name']     == req.info.channel &&
        ch['info']['genre']    == req.genre        &&
        ch['status']['source'] == req.source_uri
      }
      fail 'チャンネルはすでにあります。'
    end
  end

  post '/broadcast' do
    halt 503, h('現在チャンネルの作成はできません。') if NO_NEW_CHANNEL

    begin
      props = params.slice('channel', 'desc', 'genre', 'yp', 'url', 'comment', 'stream_type')
      channel_info = ChannelInfo.new({ user: @user }.merge(props))

      broadcast_check_params!

      serv_id = params['servent'].to_i
      case serv_id
      when -1
        servent = Servent.request_one
      else
        servent = Servent.find(serv_id) rescue nil
      end
      raise '利用可能な配信サーバーがありません。' unless servent
      breq = BroadcastRequest.new(servent, channel_info, @yellow_pages, request.ip)

      # PeerCast Station に同じ ID のチャンネルが立たないことを
      # 保証するためにロックファイルを使用する
      chid = nil
      Lockfile('tmp/lock.file') do
        ascertain_new!(servent.api, breq)
        chid = servent.api.broadcastChannel(breq.to_h)
      end

      ch = @user.channels.build(gnu_id: chid)
      ch.channel_info = channel_info
      ch.servent = servent
      ch.save!

      log.info("user #{@user.id} created channel #{ch.id}")
      @user.last_broadcast = Time.now
      @user.save!

      redirect to("/channels/#{ch.id}")
    rescue StandardError => e
      # 必要なフィールドがなかった場合などフォームを再表示する
      @message = e.message
      erb :create, locals: { template: channel_info, servents: Servent.enabled }
    end
  end

end
