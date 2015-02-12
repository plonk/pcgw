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
      @status = peercast.getChannelStatus(@channel.gnu_id)
      @info = peercast.getChannelInfo(@channel.gnu_id)

      if @channel.info['yellowPages'].any?
        @link_url = @yellow_pages.find { |y| y.name == @channel.info['yellowPages'].first['name'] }.top
        @yp_name = "【#{@channel.info['yellowPages'].first['name']}】"
      else
        @link_url = 'http://pcgw.sun.ddns.vc/'
      end
      @data_text = "【PeerCastで配信中！】#{@info['info']['name']}「#{@info['info']['desc']}」 #{@info['info']['url']} #{@yp_name}"

      erb :status
    rescue Jimson::Client::Error => e
      h "なんかエラーだって: #{e}"
    end
  end

  get '/channels/:id/update' do
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

      @connections = slim :connections, locals: { channel: @channel, connections: connections }
      js = erb :update

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

  # チャンネル情報の更新
  post '/channels/:id' do
    # チャンネル所有チェック
    halt 403, 'permission denied' if @channel.user != @user

    info = params.slice('name', 'url', 'genre', 'desc', 'comment')
    track = {
      name:    '',
      creator: '',
      genre:   '',
      album:   '',
      url:     ''
    }
    peercast.setChannelInfo(channelId: @channel.gnu_id,
                            info:      info,
                            track:     track)
    channel_info = @channel.channel_info
    new_channel_info = channel_info.dup

    channel_info.terminated_at = Time.now
    channel_info.save!

    key_map = { 'name' => 'channel' }

    new_channel_info.update!(Hash[info.map { |k,v| [key_map[k] || k, v] }])

    @channel.channel_info = new_channel_info

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

        peercast.stopChannel(@channel.gnu_id)
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

  delete '/channels/:id/connections/:connection_id' do
    halt 403, "チャンネルを所有していません。" unless @channel.user == @user

    success = peercast.stopChannelConnection(@channel.gnu_id, params['connection_id'])
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
      peercast.stopChannel(ch.gnu_id)
      ch.destroy

      log.info("user #{@user.id} destroyed channel #{ch.id}")
    end
    erb :stop
  end
end
