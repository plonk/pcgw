require_relative '../lib/yarr_client'
require_relative '../lib/bbs_reader'

class Pcgw < Sinatra::Base
  before '/channels/:id/?*' do |id, resource|
    if resource == 'update'
      # update は呼び出し元のページを JS で遷移させるので nil にするだけ。
      @channel = Channel.find(id) rescue @channel = nil
    else
      @channel = Channel.find(id) rescue halt(404, erb(:channel_not_found))
    end
  end

  # ブラウザのURLバーのように配信名がエスケープされずにぺからいぶ視聴
  # ページへのリンクをツイートしたかったけど、どうせ投稿するときに全部
  # エスケープされるので実現できなかった。↓

  # def url_escape(str)
  #   esc = -> (c) { c.bytes.map { |n| "%%%02X" % n }.join }
  #   str.each_char.map { |ch|
  #     if ch =~ /[\p{L}\p{M}\p{N}\p{P}\p{S}]/
  #       # スペースを含まない「印字可能文字」
  #       if ch =~ /[[:ascii:]]/ && ch =~ /[^abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789\-._~]/
  #         # ASCII印字可能文字でURLに使用できない集合はエスケープする。(例: # -> %23)
  #         esc.(ch)
  #       else
  #         # URLに直接書けるASCII文字や、漢字はエスケープしない。
  #         ch
  #       end
  #     else
  #       # 制御文字や空白文字はエスケープする。(例: SPC -> %20、全角空白 -> %E3%80%80)
  #       esc.(ch)
  #     end
  #   }.join
  # end

  get '/channels/:id' do
    unless @user.admin? || @channel.user == @user
      halt 403, 'permission denied'
    end

    begin
      @status = @channel.servent.api.getChannelStatus(@channel.gnu_id)
      @info = @channel.servent.api.getChannelInfo(@channel.gnu_id)

      if @channel.info['yellowPages'].any?
        yp_name = "【#{@channel.info['yellowPages'].first['name']}】"
      else
        yp_name = "PeerCast"
      end
      desc = if @info['info']['desc'].blank?
               ''
             else 
               "「#{@info['info']['desc']}」"
             end
      @data_text = "【#{yp_name}で配信中！】#{@info['info']['name']}#{desc} ぺからいぶで視聴→"
      name_escaped = ERB::Util.url_encode(@info['info']['name'])
      # Twitter のウィジェットによりベタでツイート本文に埋め込まれるた
      # め、配信名に空白が入っていると都合が悪いから、事前にエスケープ
      # しておく。
      @link_url = "http://peca.live/#{name_escaped}"

      @status_class = status_semantic_class @status['status']
      src = @channel.source_connection
      @source_kbps = src.recvRateKbps
      @bitrate_meter = bitrate_meter(@source_kbps, @info['info']['bitrate'])

      # connections = @channel.connections.select { |c| c.type == "relay" }.sort_by(&:remoteIdPort)
      # @connections = slim :connections, locals: { channel: @channel, connections: connections }, layout: false, pretty: false

      @repeater_status = channels_get_repeater_status(@channel, YarrClient.new)

      slim :status
    rescue Jimson::Client::Error => e
      h "なんかエラーだって: #{e}"
    end
  end

  def channels_get_repeater_status(channel, yarr)
    begin
      rep_src = "#{channel.push_uri}/#{channel.stream_key}"
      text = yarr.stats.select { |p| p['src'] == rep_src }
             .map { |p| "#{URI(p['dst']).hostname}に送信中" + (if p['retry_count'] > 0 then "(リトライ: #{p['retry_count']})" else "" end) }
             .join("、")
      if text == ""
        return "なし"
      else
        return text
      end
    rescue => e
      return "リピーター状態取得エラー: #{e.message}"
    end
  end

  # ソースストリーム接続のリスタート
  get '/channels/:id/reset' do
    halt 403, "permission denied" unless @channel.user == @user or @user.admin?

    src = @channel.connections.find { |c| c.type == "source" }
    halt 500, "source connection not found" unless src

    @channel.servent.api.restartChannelConnection(@channel.gnu_id, src.connectionId)

    redirect to "/channels/#{@channel.id}"
  end

  # Ajax エンドポイント
  get '/channels/:id/update' do
    if @channel
      unless @user.admin? || @channel.user == @user
        halt 403, 'permission denied'
      end
    else
      # チャンネルが存在しない場合はページ自体のリロードを促す。所有判
      # 定はできない。
      js = "$(window).off('beforeunload'); location.reload();"
      return [200,
              { 'Content-Type' => 'text/javascript',
                'Content-Length' => js.bytesize.to_s }, [js]]
    end

    begin
      @error = nil
      @status = @channel.status
      @info = @channel.info
      @status_class = status_semantic_class @status['status']

      src = @channel.source_connection
      @source_kbps = src.recvRateKbps
      @bitrate_meter = bitrate_meter(@source_kbps, @info['info']['bitrate'])

      # connections = @channel.connections.select { |c| c.type == "relay" }.sort_by(&:remoteIdPort)
      # @connections = slim :connections, locals: { channel: @channel, connections: connections }, layout: false, pretty: false

      @repeater_status = channels_get_repeater_status(@channel, YarrClient.new)

      js = erb :update, layout: false

      [200,
       { 'Content-Type' => 'text/javascript', 'Content-Length' => js.bytesize.to_s },
       [js]]
    rescue => e
      @error = e.message
      js = erb :update, layout: false
      [200,
       { 'Content-Type' => 'text/javascript', 'Content-Length' => js.bytesize.to_s },
       [js]]
    end
  end

  get '/channels/:id/edit' do
    if @channel.user == @user
      @info = @channel.info['info']
      @channel_id = @channel.id
      erb :edit
    else
      halt(403, h("そのチャンネルは、#{@user.name}のチャンネルではありません。"))
    end
  end

  def map_keys(hash, key_map)
    hash.map { |k,v| [key_map[k] || k, v] }.to_h
  end

  # チャンネル情報の更新
  post '/channels/:id' do
    # API の name キーは ChannelInfo の channel にマップされる。
    key_map = { 'name' => 'channel' }

    # チャンネル所有チェック
    halt 403, 'permission denied' if @channel.user != @user

    info = params.slice('name', 'url', 'genre', 'desc', 'comment')
    # Peercast (YT)のチャンネル情報の各フィールドには255バイトまでし
    # か入らないので、それを越える文字列は弾く。YT 側で文字境界を無
    # 視した切り詰めが行われると問題を生じるのでそれを回避する意味が
    # ある。
    halt 400, 'チャンネル名が長すぎます'  if params['name']&.bytesize > 255
    halt 400, 'コンタクトURLが長すぎます' if params['url']&.bytesize > 255
    halt 400, 'ジャンルが長すぎます'      if params['genre']&.bytesize > 255
    halt 400, '詳細が長すぎます'          if params['desc']&.bytesize > 255
    halt 400, 'コメントが長すぎます'      if params['comment']&.bytesize > 255
    @channel.servent.api.setChannelInfo(channelId: @channel.gnu_id,
                                        info:      info,
                                        track:     @channel.info['track'])

    # 内容が変更された場合は新しい番組枠を作る
    if info['desc'] != @channel.channel_info.desc
      channel_info = @channel.channel_info
      new_channel_info = channel_info.dup

      channel_info.terminated_at = Time.now
      channel_info.save!

      new_channel_info.update!(map_keys(info, key_map))

      # ここで古い channel_info から channel への参照が破棄される。
      @channel.channel_info = new_channel_info
    else
      @channel.channel_info.update!(map_keys(info, key_map))
    end

    redirect to("/channels/#{@channel.id}")
  end

  get '/channels/:id/update_contact_url' do
    # チャンネル所有チェック
    halt 403, 'permission denied' if @channel.user != @user

    halt 400, 'url missing' if params['url'].blank?

    info = @channel.info['info']
    info['url'] = params['url']
    @channel.servent.api.setChannelInfo(channelId: @channel.gnu_id,
                                        info:      info,
                                        track:     @channel.info['track'])
    @channel.channel_info.update!(params.slice('url'))

    redirect to("/channels/#{@channel.id}")
  end

  get '/channels/:id/thread_list' do
    board = Bbs::create_board(@channel.channel_info.url)
    halt 404, "掲示板のURLではないようです: #{@channel.channel_info.url}" unless board
    begin
      threads = board.threads
    rescue RuntimeError => e # スレ一覧のフォーマットがおかしい時とか。
      halt 404, e.message
    end
    slim :thread_list, locals: { board: board, threads: threads }
  end

  # get '/channels/:id/play' do
  #   unless @channel.user == @user
  #     halt 403, '再生できるのはチャンネルの配信者だけです。'
  #   end
  #   slim :play, locals: { channel: @channel }
  # end

  post '/channels/:id/stop' do
    begin
      # チャンネルの所有者であるかのチェック
      if @user.admin? || @channel.user == @user
        # チャンネルをdestroyするのでinfoを取っておく。
        @channel_info = @channel.info

        if @channel.channel_info.stream_type == "FLV"
          src = get_source_uri_with_key(@channel)
          if src.scheme == 'rtmp'
            stop_repeaters(src.to_s)
          end
        end

        @channel.servent.api.stopChannel(@channel.gnu_id)
        @channel.destroy

        log.info("user #{@user.id} destroyed channel #{@channel.id}")

        erb :stop
      else
        halt 403, "そのチャンネルは#{@user.name}のチャンネルではありません。"
      end
    rescue Jimson::Client::Error => e
      h e.inspect
    end
  end

  get '/channels/:id/relay_tree' do
    ary = @channel.servent.api.getChannelRelayTree(@channel.gnu_id)
    root_nodes = ary.map(&RelayTree.method(:new))
    fertility = root_nodes.map { |r| r.fertility_count }.inject(0,:+)

    slim :relay_tree, locals: { root_nodes: root_nodes, fertility: fertility }
  end

  get '/channels/:id/local_relays' do
    @info = @channel.servent.api.getChannelInfo(@channel.gnu_id)
    connections = @channel.connections.select { |c| c.type == "relay" }.sort_by { |c| c.remoteIdPort.upcase }
    @connections = slim :connections, locals: { channel: @channel, connections: connections }, layout: false, pretty: false

    slim :local_relays
  end

  delete '/channels/:id/connections/:connection_id' do
    halt 403, "チャンネルを所有していません。" unless @channel.user == @user

    success = @channel.servent.api.stopChannelConnection(@channel.gnu_id, params['connection_id'].to_i)
    if success
      flash[:success] = "接続を切断しました。"
      redirect back
    else
      "接続は切断できませんでした。"
    end
  end

  get '/channels/?' do
    channels = Channel.all
    slim :channels, locals: { channels: channels }
  end

  get '/channels/:id/create_repeater' do
    slim :create_repeater, locals: {}
  end

  post '/channels/:id/start_repeater' do
    src = URI.parse(@channel.push_uri + "/" + @channel.stream_key)
    dst = URI.parse(params[:stream_url] + "/" + params[:key])
    unless src.scheme == "rtmp"
      halt 400, "Bad protocol #{src.scheme.inspect} in source URL"
    end
    unless dst.scheme == "rtmp"
      halt 400, "Bad protocol #{dst.scheme.inspect} in destination URL"
    end
    yarr = YarrClient.new
    pid = yarr.start(src.to_s, dst.to_s)
    log.info("user #{@user.id} started repeater (pid #{pid})")
    redirect to("/channels/#{@channel.id}")
  end

  def get_source_uri_with_key(channel)
    return URI.parse(channel.push_uri + "/" + channel.stream_key)
  end

  def stop_repeaters(repeater_src_string)
    yarr = YarrClient.new
    yarr.stats.each do |process|
      if process['src'] == repeater_src_string
        success = yarr.kill(process['pid'])
        if success
          log.info("repeater #{process['pid']} killed")
        else
          log.error("failed to kill repeater #{process['pid']}")
        end
      end
    end
  end

  get '/channels/:id/stop_repeater' do
    if @channel.channel_info.stream_type != "FLV"
      halt 400, "Not an FLV stream"
    end
    src = get_source_uri_with_key(@channel)
    unless src.scheme == "rtmp"
      halt 400, "Bad protocol #{src.scheme.inspect} in source URL"
    end

    stop_repeaters(src.to_s)

    redirect to("/channels/#{@channel.id}")
  end
end
