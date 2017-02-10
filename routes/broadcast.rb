require 'lockfile'

# チャンネル作成要求を表わすクラス。
class PeercastStationBroadcastRequest
  attr_reader :info

  def initialize(servent, ch_info, yellow_pages, client_ip)
    @servent = servent
    @info = ch_info
    @yellow_pages = yellow_pages
    @client_ip = client_ip
  end

  def genre
    if !yp
      @info.genre
    else
      yp.add_prefix(@info.genre)
    end
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

  def issue
    @servent.api.broadcastChannel(to_h)
  end

  private

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

  def source_uri_rtmp(user)
    port = 9000 + user.id
    "rtmp://#{@servent.hostname}:#{port}/live/livestream"
  end

  def source_uri_http(user)
    path = "#{9000 + user.id}"
    "http://#{WM_MIRROR_HOSTNAME}:5000/#{path}"
  end

end

class PeercastBroadcastRequest
  attr_reader :info

  def initialize(servent, ch_info, yellow_pages, client_ip)
    @servent = servent
    @info = ch_info
    @yellow_pages = yellow_pages
    # いまのところ使い道ないけど一応もっとく。
    @client_ip = client_ip
  end

  def genre
    if !yp
      @info.genre
    else
      yp.add_prefix(@info.genre)
    end
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

  def issue
    id = @servent.api.fetch(to_h)

    json = @servent.api.getChannelInfo(id)

    json['info']['comment'] = @info.comment
    json['track']['creator'] = "#{@client_ip} via Peercast Gateway"
    @servent.api.setChannelInfo(id, json['info'], json['track'])

    id
  end

  private

  def yp
    if @info.yp.blank?
      nil
    else
      ret = @yellow_pages.find { |y| y.name == @info.yp }
      fail "yellow page #{@info.yp.inspect} not found" unless ret
      ret
    end
  end

  def to_h
    {
      url: source_uri,
      name: @info.channel,
      desc: @info.desc,
      genre: genre,
      contact: @info.url,
      bitrate: 0,
      type: @info.stream_type
    }
  end

  def source_uri_rtmp(user)
    "http://#{WM_MIRROR_HOSTNAME}:6000/live/#{9000 + user.id}"
  end

  def source_uri_http(user)
    "http://#{WM_MIRROR_HOSTNAME}:5000/#{9000 + user.id}"
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

    programs = ChannelInfo.where(user: @user).order(created_at: :desc).limit(10)

    erb :create, locals: { template: template, servents: Servent.enabled, recent_programs: programs }
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

  def choose_servent(serv_id, yp)
    case serv_id
    when -1
      servent = Servent.request_one(yp)
      unless servent
        raise '利用可能な配信サーバーがありません。'
      end
    else
      begin
        servent = Servent.find(serv_id)
      rescue
        raise '指定のサーバーが見付かりません。'
      end

      unless servent.enabled
        raise '指定のサーバーは現在無効化されています。'
      end

      unless servent.vacancies > 0
        raise '指定のサーバーにはこれ以上チャンネルを作成できません。'
      end

      unless servent.yellow_pages.split(' ').include?(yp)
        raise "指定のサーバーはイエローページ#{yp}に対応していません。"
      end
    end
    servent
  end

  post '/broadcast' do
    halt 503, h('現在チャンネルの作成はできません。') if NO_NEW_CHANNEL

    begin
      props = params.slice('channel', 'desc', 'genre', 'yp', 'url', 'comment', 'stream_type')
      channel_info = ChannelInfo.new({ user: @user }.merge(props))

      broadcast_check_params!

      servent = choose_servent(params['servent'].to_i, params['yp'])
      case servent.agent
      when /^PeerCastStation\//
        breq = PeercastStationBroadcastRequest.new(servent, channel_info, @yellow_pages, request.ip)
      when /^PeerCast\//
        breq = PeercastBroadcastRequest.new(servent, channel_info, @yellow_pages, request.ip)
      end

      # PeerCast Station に同じ ID のチャンネルが立たないようにする。
      ascertain_new!(servent.api, breq)
      chid = breq.issue

      ch = @user.channels.build(gnu_id: chid)
      ch.channel_info = channel_info
      ch.servent = servent
      ch.save!

      log.info("user #{@user.id} created channel #{ch.id}")

      redirect to("/channels/#{ch.id}")
    rescue RuntimeError => e
      # 必要なフィールドがなかった場合などフォームを再表示する
      @message = e.message
      programs = ChannelInfo.where(user: @user).order(created_at: :desc).limit(10)
      erb :create, locals: { template: channel_info, servents: Servent.enabled, recent_programs: programs }
    end
  end

end
