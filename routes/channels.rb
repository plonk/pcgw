class Pcgw < Sinatra::Base
  before '/channels/:id/?*' do |id, _|
    @channel = Channel.find(id) rescue halt(404, 'channel not found')
  end

  get '/channels/:id' do
    begin
      @status = peercast.getChannelStatus(@channel.gnu_id)
      @info = peercast.getChannelInfo(@channel.gnu_id)

      if @channel.info['yellowPages'].any?
        @link_url = yellow_page_home @channel.info['yellowPages'].first['name']
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
    begin
      @error = nil
      @status = peercast.getChannelStatus(@channel.gnu_id)
      @info = peercast.getChannelInfo(@channel.gnu_id)
      @status_class = status_semantic_class @status['status']

      src = source_stream(@channel)
      @source_kbps = (src['recvRate'] * 8 / 1000).round
      js = erb :update

      [200,
       { 'Content-Type' => 'text/javascript', 'Content-Length' => js.bytesize.to_s },
       [js]]
    rescue Jimson::Client::Error => e
      @error = e.message
      js = erb :update
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
    redirect to("/channels/#{@channel.id}")
  end

  get '/channels/:id/play' do
    slim :play, locals: { channel: @channel }
  end

  post '/channels/:id/stop' do
    begin
      # チャンネルの所有者であるかのチェック
      if @channel.user == @user
        @channel_infos = [@channel.info]

        peercast.stopChannel(@channel.gnu_id)
        @channel.destroy

        erb :stop
      else
        halt 403, "そのチャンネルは#{@user.name}のチャンネルではありません。"
      end
    rescue Jimson::Client::Error => e
      h e.inspect
    end
  end

  post '/stopall' do
    @channel_infos = []
    ids = params[:channel_ids].map(&:to_i)
    channels = @user.channels.select { |ch| ids.include?(ch.id) }
    channels.each do |ch|
      @channel_infos << ch.info
      peercast.stopChannel(ch.gnu_id)
      ch.destroy
    end
    erb :stop
  end
end
