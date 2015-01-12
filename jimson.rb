# -*- coding: utf-8 -*-
require 'jimson'
require 'sinatra/base'
require_relative 'peercast'
require 'active_support/core_ext'
require 'omniauth-twitter'
require 'active_record'
require_relative 'models/channel'
require_relative 'models/user'
require_relative 'jp'
require 'pp'
require 'sinatra/cookies'
require 'ostruct'

# 初期化処理
require_relative 'init'

def get_peercast
  Peercast.new(PEERCAST_STATION_PRIVATE_IP, 7144)
end

# Peercast Gateway アプリケーションクラス
class Pcgw < Sinatra::Base
  helpers Sinatra::Cookies
  use Rack::MethodOverride

  NO_NEW_CHANNEL = false

  configure do
    use Rack::Session::Cookie, expire_after: 30.days.to_i, secret: ENV['CONSUMER_SECRET']

    set :cookie_options do
      { expires: Time.now + 30.days.to_i }
    end

    use OmniAuth::Builder do
      provider :twitter, ENV['CONSUMER_KEY'], ENV['CONSUMER_SECRET']
    end
  end

  require_relative 'helpers'

  before do
    @yellow_pages = get_peercast.process_call(:getYellowPages, []).map(&OpenStruct.method(:new))

    # /auth/ で始まる URL なら omniauth-twitter に任せる。
    pass if request.path_info =~ %r{^/auth/}

    # / はログインしていなくてもアクセスできる。
    pass if request.path_info == '/'
    pass if request.path_info =~ %r{^/doc($|/)}

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
      p env['omniauth.auth']
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
    erb :top
  end

  get '/doc/?' do
    get_user
    erb :doc
  end

  get '/doc/:name' do
    docs = %w[how-to-obs how-to-wme desc]
    halt 404 unless docs.include? params['name']

    get_user
    erb params['name'].to_sym
  end

  get '/create' do
    halt 503, h('現在チャンネルの作成はできません。') if NO_NEW_CHANNEL

    get_user
    params.merge!(cookies.to_h.slice('channel', 'genre', 'comment', 'desc', 'yp', 'url', 'type'))
    params['channel'] ||= @user.name
    erb :create
  end

  get '/home' do
    get_user
    @channels = @user.channels.select(&:exist?)
    erb :home
  end

  post '/broadcast' do
    halt 503, h('現在チャンネルの作成はできません。') if NO_NEW_CHANNEL

    get_user
    begin
      raise 'チャンネル名が入力されていません'     if params['channel'].blank?
      raise '掲載YPが選択されていません'           if params['yp'].blank?
      raise 'ストリームタイプが選択されていません' if params['type'].blank?
      # raise 'ジャンルが入力されていません'     if params['genre'].blank?
      # raise '詳細が入力されていません'         if params['desc'].blank?

      peercast = get_peercast
      yps = peercast.process_call(:getYellowPages, [])

      case pcgw_env
      when 'development'
        ypid = nil
        genre = params['genre']
      when 'production'
        ypid = params['yp'].to_i
        yp = yps.find { |y| y['yellowPageId'] == params['yp'].to_i }
        prefix = yp['name'].downcase
        if params['genre'] =~ /^#{prefix}/
          genre = params['genre']
        else
          genre = "#{prefix}#{params['genre']}"
        end
      else
        fail
      end

      # 入力内容をクッキーに保存
      cookies.merge! params.slice('channel', 'desc', 'genre', 'yp', 'url', 'comment', 'type')

      info = {
        name:     params['channel'],
        url:      params['url'],
        bitrate:  '',
        mimeType: '',
        genre:    genre,
        desc:     params['desc'],
        comment:  params['comment']
      }
      track = {
        name:    '',
        creator: '',
        genre:   '',
        album:   '',
        url:     ''
      }
      args = {
        yellowPageId:  ypid,
        info: info,
        track: track,
      }
      if params['type'] == 'WMV'
        args = args.merge(sourceUri: source_uri_http(@user),
                          sourceStream: 'http',
                          contentReader: 'ASF(WMV or WMA)')
      elsif params['type'] == 'FLV'
        args = args.merge(sourceUri: source_uri_rtmp(@user),
                          sourceStream: 'RTMP Source',
                          contentReader: 'Flash Video (FLV)')
      else
        fail "unknown stream type #{params['type']}"
      end
      gnuid = peercast.process_call(:broadcastChannel, args)

      @user.channels.build(gnu_id: gnuid).save!

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
      pc = get_peercast

      @status = pc.process_call(:getChannelStatus, [ params[:channel_id] ])
      @info = pc.process_call(:getChannelInfo, [ params[:channel_id] ])
      @channel = Channel.find_by(gnu_id: params[:channel_id])
      if @channel.info['yellowPages'].any?
        @link_url = yellow_page_home(@channel.info['yellowPages'].first['name'])
        @yp_name = "【#{@channel.info['yellowPages'].first['name']}】"
      else
        @link_url = "http://pcgw.sun.ddns.vc/"
      end

      erb :status
    rescue Jimson::Client::Error => e
      h "なんかエラーだって: #{e}"
    end
  end

  def status_class(status)
    case status
    when "Receiving"
      "text-success"
    when "Error", "Searching"
      "text-warning"
    else
      "text-error"
    end
  end

  get '/channels/:channel_id/update' do
    begin
      @error = nil
      pc = get_peercast
      @status = pc.process_call(:getChannelStatus, [ params[:channel_id] ])
      @info = pc.process_call(:getChannelInfo, [ params[:channel_id] ])
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

        pc = get_peercast
        pc.process_call(:stopChannel, [ ch.gnu_id ])
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
    pc = get_peercast
    channels.each do |ch|
      @channel_infos << ch.info
      pc.process_call(:stopChannel, [ch.gnu_id])
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
    # チャンネル所有チェック

    info = params.slice('name', 'url', 'genre', 'desc', 'comment')
    pp info
    track = {
      name:    '',
      creator: '',
      genre:   '',
      album:   '',
      url:     ''
    }
    get_peercast.process_call(:setChannelInfo,
                              {
                                channelId: params[:channel_id],
                                info: info,
                                track: track
                              })
    redirect to("/channels/#{params['channel_id']}")
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
    p params
    ps = params.slice(*%w(name image admin twitter_id))
    p ps
    @content_user.update!(ps)
    @content_user.save!
    redirect to("/users/#{@content_user.id}")
  end
end
