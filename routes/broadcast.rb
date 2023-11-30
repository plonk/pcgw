# coding: utf-8
# チャンネル作成要求を表わすクラス。
class PeercastBroadcastRequest
  attr_reader :info

  def initialize(servent, ch_info, yellow_pages, client_ip, key)
    @servent = servent
    @info = ch_info
    @yellow_pages = yellow_pages
    # いまのところ使い道ないけど一応もっとく。
    @client_ip = client_ip
    @key = key
  end

  def genre
    if !yp
      @info.genre
    else
      yp.add_prefix(@info.genre)
    end
  end

  # PeerCastがFetchするURL
  def source_uri
    case @info.stream_type
    when 'WMV'
      "http://#{WM_MIRROR_HOSTNAME}:5000/#{@key}"
    when 'FLV'
      "rtmp://#{WM_MIRROR_HOSTNAME}/live/#{@key}"
    when 'MKV'
      "http://#{WM_MIRROR_HOSTNAME}:7000/#{@key}"
    else
      fail 'Unsupported stream type'
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
      type: @info.stream_type,
      network: yp ? yp.network : 'ipv4'
    }
  end

 public
  # ユーザーがPushするURL
  def push_uri
    case @info.stream_type
    when 'WMV'
      "http://#{WM_MIRROR_HOSTNAME}:5000/#{@key}"
    when 'FLV'
      "rtmp://#{WM_MIRROR_HOSTNAME}/live"
    when 'MKV'
      "http://#{WM_MIRROR_HOSTNAME}:7000/#{@key}"
    else
      fail 'unsupported stream type'
    end
  end

  # ユーザーがPushする時に使うキー
  def stream_key
    case @info.stream_type
    when 'WMV', 'MKV'
      nil
    when 'FLV'
      @key
    else
      fail 'unsupported stream type'
    end
  end
end

class Pcgw < Sinatra::Base
  get '/create' do
    halt 503, h('現在チャンネルの作成はできません。') if NO_NEW_CHANNEL
    #halt 503, h('有効なサーバーがないのでチャンネルの作成ができません。') if Servent.enabled.empty?

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

  # id: Source ID or zero if default
  def source_to_key(id)
    case id
    when 0
      return (9000 + @user.id).to_s
    else
      src = @user.sources.find(id)
      if src
        return src.key
      else
        return nil
      end
    end
  end

  def source_name(id)
    case id
    when 0
      return nil
    else
      src = @user.sources.find(id)
      if src
        return src.name
      else
        return nil
      end
    end
  end
  
  post '/broadcast' do
    halt 503, h('現在チャンネルの作成はできません。') if NO_NEW_CHANNEL

    begin
      props = params.slice('channel', 'desc', 'genre', 'yp', 'url', 'comment', 'stream_type', 'hide_screenshots')
      channel_info = ChannelInfo.new({ user: @user }.merge(props))
      key = source_to_key(params['source'].to_i)
      channel_info.source_name = source_name(params['source'].to_i)

      unless key
        # 存在しないか、要求元のユーザーが所有しないソースが指定された。
        halt 403, "存在しないソースです。"
      end

      fail 'チャンネル名が入力されていません'     if params['channel'].blank?
      fail 'ストリームタイプが選択されていません' if params['stream_type'].blank?

      servent = choose_servent(params['servent'].to_i, params['yp'])
      channel_info.servent = servent
      breq = PeercastBroadcastRequest.new(servent, channel_info, @yellow_pages, request.ip, key)

      # 同じ ID のチャンネルが立たないようにする。
      ascertain_new!(servent.api, breq)
      chid = breq.issue

      ch = @user.channels.build(gnu_id: chid)
      ch.channel_info = channel_info
      ch.hide_screenshots = params['hide_screenshots']
      ch.servent = servent
      ch.push_uri = breq.push_uri
      ch.stream_key = breq.stream_key
      ch.save!

      log.info("user #{@user.id} created channel #{ch.id}")

      redirect to("/channels/#{ch.id}")
    rescue RuntimeError => e
      # 必要なフィールドがなかった場合などフォームを再表示する
      flash.now[:danger] = e.message
      programs = ChannelInfo.where(user: @user).order(created_at: :desc).limit(10)
      erb :create, locals: { template: channel_info, servents: Servent.enabled, recent_programs: programs }
    end
  end

end
