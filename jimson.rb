# -*- coding: utf-8 -*-
require 'jimson'
require 'sinatra/base'
require_relative 'peercast'
require 'active_support/core_ext'
require 'omniauth-twitter'
require 'active_record'
require_relative 'models/channel'
require_relative 'models/user'
require_relative 'models/channel_info'
require_relative 'jp'
require 'sinatra/cookies'
require 'ostruct'
require 'slim'

# 初期化処理
require_relative 'init'

def peercast
  $peercast ||= Peercast.new(PEERCAST_STATION_PRIVATE_IP, 7144)
end

# Peercast Gateway アプリケーションクラス
class Pcgw < Sinatra::Base
  helpers Sinatra::Cookies
  use Rack::MethodOverride

  NO_NEW_CHANNEL = false

  configure do
    use Rack::Session::Cookie, expire_after: 30.days.to_i, secret: ENV['CONSUMER_SECRET']
    Slim::Engine.set_default_options pretty: true

    set :cookie_options do
      { expires: Time.now + 30.days.to_i }
    end

    use OmniAuth::Builder do
      provider :twitter, ENV['CONSUMER_KEY'], ENV['CONSUMER_SECRET']
    end
  end

  require_relative 'helpers'

  before do
    @yellow_pages = peercast.getYellowPages.map(&OpenStruct.method(:new))

    # /auth/ で始まる URL なら omniauth-twitter に任せる。
    pass if request.path_info =~ %r{^/auth/}


    # 以下のページはログインしていなくてもアクセスできる。
    # トップページ
    pass if request.path_info == '/'
    # ヘルプ
    pass if request.path_info =~ %r{^/doc($|/)}
    # プロフィール
    pass if request.path_info =~ %r{^/profile/}

    # ログインされていなかったらログインさせる。
    redirect to('/auth/twitter') unless logged_in?
  end

  after do
    ActiveRecord::Base.connection.close
  end

  # ログイン成功
  get '/auth/twitter/callback' do
    # twitter から取得した名前とアイコンをセッションに設定する。

    if (user = User.find_by(twitter_id: env['omniauth.auth']['uid']))
      session[:uid] = user.id.to_s
      redirect '/home'
    else
      user = User.new(name:       env['omniauth.auth']['info']['name'],
                      image:      env['omniauth.auth']['info']['image'],
                      twitter_id: env['omniauth.auth']['uid'])
      user.save
      session[:uid] = user.id.to_s

      redirect to('/newuser')
    end
  end

  get '/newuser' do
    get_user
    erb :newuser
  end

  # ログイン失敗。ユーザーがアプリの認証を拒否した場合。
  get '/auth/failure' do
    '認証できませんでした'
  end

  # ログアウト。セッションをクリアする。
  get '/logout' do
    session.clear
    redirect to('/')
  end

  # ルート。
  get '/' do
    get_user
    @channels = Channel.all.select(&:exist?)
    erb :top, locals: { recent_programs: ChannelInfo.all.order(created_at: :desc).limit(10) }
  end

  get '/doc/?' do
    get_user
    erb :doc
  end

  get '/doc/:name' do
    docs = %w(how-to-obs how-to-wme desc)
    halt 404 unless docs.include? params['name']

    get_user
    erb params['name'].to_sym
  end

  get '/create' do
    halt 503, h('現在チャンネルの作成はできません。') if NO_NEW_CHANNEL

    get_user
    params.merge!(cookies.to_h.slice('channel', 'genre', 'comment', 'desc', 'yp', 'url', 'stream_type'))
    params['channel'] ||= @user.name
    erb :create
  end

  get '/home' do
    get_user
    @channels = @user.channels.select(&:exist?)
    programs = ChannelInfo.where(user: @user).order(created_at: :desc).limit(10)
    erb :home, {}, recent_programs: programs
  end

  # YP の ID とジャンル文字列を params から決定する。
  def yellow_page_id_and_genre
    case pcgw_env
    when 'development'
      ypid = nil
      genre = params['genre']
    when 'production'
      ypid = params['yp'].to_i
      yp = peercast.getYellowPages.find { |y| y['yellowPageId'] == params['yp'].to_i }
      prefix = yp['name'].downcase
      if params['genre'] =~ /^#{prefix}/
        genre = params['genre']
      else
        genre = "#{prefix}#{params['genre']}"
      end
    else
      fail
    end
    [ypid, genre]
  end

  def broadcast_check_params
    fail 'チャンネル名が入力されていません'     if params['channel'].blank?
    fail '掲載YPが選択されていません'           if params['yp'].blank?
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

    get_user
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
      unless @user.channels.find_by(gnu_id: gnuid)
        @user.channels.build(gnu_id: gnuid).save!
      end
      channel_info.save!

      redirect to("/channels/#{gnuid}")
    rescue StandardError => e
      # 必要なフィールドがなかった場合などフォームを再表示する
      @message = e.message
      erb :create
    end
  end

  get '/channels/:channel_id' do
    get_user
    begin
      @status = peercast.getChannelStatus(params[:channel_id])
      @info = peercast.getChannelInfo(params[:channel_id])
      @channel = Channel.find_by(gnu_id: params[:channel_id])
      halt 404, 'channel not found' unless @channel
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

  def status_class(status)
    case status
    when 'Receiving'
      'text-success'
    when 'Error', 'Searching'
      'text-warning'
    else
      'text-error'
    end
  end

  get '/channels/:channel_id/update' do
    begin
      @error = nil
      @status = peercast.getChannelStatus(params[:channel_id])
      @info = peercast.getChannelInfo(params[:channel_id])
      @status_class = status_class @status['status']
      js = erb :update

      [
        200,
        {
          'Content-Type' => 'text/javascript',
          'Content-Length' => js.bytesize.to_s
        },
        [js]
      ]
    rescue Jimson::Client::Error => e
      @error = e.message
      js = erb :update
      [
        200,
        {
          'Content-Type' => 'text/javascript',
          'Content-Length' => js.bytesize.to_s
        },
        [js]
      ]
    end
  end

  get '/channels/:channel_id/edit' do
    get_user
    ch = @user.channels.find_by(gnu_id: params[:channel_id])
    if ch
      @info = ch.info['info']
      @channel_id = params[:channel_id]
      erb :edit
    else
      h "#{params[:channel_id]}は#{@user.name}のチャンネルじゃないです。"
    end
  end

  post '/stop' do
    get_user
    begin
      # チャンネルの所有者であるかのチェック
      ch = @user.channels.find_by(gnu_id: params[:channel_id])

      if ch
        @channel_infos = [ch.info]

        peercast.stopChannel(ch.gnu_id)
        ch.destroy

        erb :stop
      else
        h "#{params[:channel_id]}は#{@user.name}のチャンネルではないです。"
      end
    rescue Jimson::Client::Error => e
      h e.inspect
    end
  end

  post '/stopall' do
    get_user

    @channel_infos = []
    channels = []
    @user.channels.each do |ch|
      channels << ch if params[:channel_ids].include?(ch.gnu_id) && ch.exist?
    end
    channels.each do |ch|
      @channel_infos << ch.info
      peercast.stopChannel(ch.gnu_id)
      ch.destroy
    end
    erb :stop
  end

  get '/account' do
    get_user
    erb :account
  end

  post '/account' do
    get_user
    @user.update!(params.slice('name'))
    @success_message = '変更を保存しました。'
    erb :account
  end

  get '/cleanup' do
    msg = []
    Channel.all.each do |ch|
      next if ch.exist?

      msg << "ユーザー番号#{ch.user_id}の#{ch.gnu_id}を削除した"
      ch.destroy
    end
    msg.join('<br>')
  end

  # チャンネル情報の更新
  post '/channels/:channel_id' do
    # チャンネル存在チェック。PCGWに関係ないチャンネルは変更しない
    channel = Channel.find_by(gnu_id: params['channel_id'])
    halt 404, 'channel not found' unless channel
    # チャンネル所有チェック
    get_user
    halt 403, 'permission denied' if channel.user != @user

    info = params.slice('name', 'url', 'genre', 'desc', 'comment')
    track = {
      name:    '',
      creator: '',
      genre:   '',
      album:   '',
      url:     ''
    }
    peercast.setChannelInfo(channelId: params[:channel_id],
                            info:      info,
                            track:     track)
    redirect to("/channels/#{params['channel_id']}")
  end

  get '/profile/:id' do
    get_user
    user = User.find(params['id']) rescue halt(404, 'user not found')
    programs = ChannelInfo.where(user: user).order(created_at: :desc).limit(10)

    slim :profile, {}, user: user, recent_programs: programs
  end

  get '/users/:id' do
    get_user
    must_be_admin!(@user)

    @content_user = User.find(params[:id])
    erb :user
  end

  # ユーザーを削除
  delete '/users/:id' do
    get_user
    must_be_admin!(@user)

    @content_user = User.find(params[:id])
    @content_user.destroy!
    erb :delete_user
  end

  get '/users' do
    redirect to('/users/')
  end

  # ユーザー一覧
  get '/users/' do
    get_user
    must_be_admin!(@user)

    @users = User.all
    erb :users
  end

  # ユーザー編集画面
  get '/users/:id/edit' do
    get_user
    must_be_admin!(@user)

    @content_user = User.find(params[:id])
    erb :user_edit
  end

  # ユーザー情報を変更
  patch '/users/:id' do
    get_user
    must_be_admin!(@user)

    @content_user = User.find(params[:id])
    ps = params.slice(*%w(name image admin twitter_id))
    @content_user.update!(ps)
    @content_user.save!
    redirect to("/users/#{@content_user.id}")
  end
end
