class Pcgw < Sinatra::Base
  before '/channels/:id/?*' do |id, resource|
    if resource == 'update'
      # update は呼び出し元のページを JS で遷移させるので nil にするだけ。
      @channel = Channel.find(id) rescue @channel = nil
    else
      @channel = Channel.find(id) rescue halt(404, erb(:channel_not_found))
    end
  end

  get '/channels/:id' do
    begin
      @status = @channel.servent.api.getChannelStatus(@channel.gnu_id)
      @info = @channel.servent.api.getChannelInfo(@channel.gnu_id)

      if @channel.info['yellowPages'].any?
        @link_url = @yellow_pages.find { |y| y.name == @channel.info['yellowPages'].first['name'] }.top
        @yp_name = "【#{@channel.info['yellowPages'].first['name']}】"
      else
        @link_url = 'http://pcgw.sun.ddns.vc/'
      end
      @data_text = "【PeerCastで配信中！】#{@info['info']['name']}「#{@info['info']['desc']}」 #{@info['info']['url']} #{@yp_name}"

      slim :status
    rescue Jimson::Client::Error => e
      h "なんかエラーだって: #{e}"
    end
  end

  # ソースストリーム接続のリスタート
  get '/channels/:id/reset' do
    halt 403, "permission denied" unless @channel.user == @user

    src = @channel.connections.find { |c| c.type == "source" }
    halt 500, "source connection not found" unless src

    @channel.servent.api.restartChannelConnection(@channel.gnu_id, src.connectionId)

    redirect to "/channels/#{@channel.id}"
  end

  # Ajax エンドポイント
  get '/channels/:id/update' do
    # チャンネルが存在しない場合はページ自体のリロードを促す
    unless @channel
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

      src = @channel.source_stream
      @source_kbps = src.recvRateKbps
      connections = @channel.connections.select { |c| c.type == "relay" }

      @connections = slim :connections, locals: { channel: @channel, connections: connections }, layout: false
      js = erb :update, layout: false

      [200,
       { 'Content-Type' => 'text/javascript', 'Content-Length' => js.bytesize.to_s },
       [js]]
    rescue => e
      @error = e.message
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

  get '/channels/:id/play' do
    slim :play, locals: { channel: @channel }
  end

  post '/channels/:id/stop' do
    begin
      # チャンネルの所有者であるかのチェック
      if @user.admin? || @channel.user == @user
        @channel_infos = [@channel.info]

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

  delete '/channels/:id/connections/:connection_id' do
    halt 403, "チャンネルを所有していません。" unless @channel.user == @user

    success = @channel.servent.api.stopChannelConnection(@channel.gnu_id, params['connection_id'])
    if success
      redirect back
    else
      "接続は切断できませんでした。"
    end
  end

  get '/channels/?' do
    channels = Channel.all
    slim :channels, locals: { channels: channels }
  end

  post '/stopall' do
    @channel_infos = []
    ids = params[:channel_ids].map(&:to_i)
    channels = @user.channels.select { |ch| ids.include?(ch.id) }
    channels.each do |ch|
      @channel_infos << ch.info
      ch.servent.api.stopChannel(ch.gnu_id)
      ch.destroy

      log.info("user #{@user.id} destroyed channel #{ch.id}")
    end
    erb :stop
  end

  get '/channels/:id/screenshot' do
    path = "screenshots/#{@channel.gnu_id}.jpg"
    if File.exist? path
      return [200, { 'Content-Type' => 'image/jpeg' }, File.read(path)]
    else
      redirect to '/images/blank_screen.png'
    end
  end

end
