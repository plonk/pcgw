# -*- coding: utf-8 -*-
require 'jimson'
require 'sinatra/base'
require 'sinatra/content_for'
require 'oauth'
require 'active_record'
require 'sinatra/cookies'
require 'ostruct'
require 'slim'
require 'logger'
require 'fileutils'
require 'omniauth'
require 'omniauth/twitch'
require 'omniauth/twitter2'

require_relative 'lib/logging'
require_relative 'lib/peercast'

# 初期化処理
require_relative 'init'
require 'rack-flash'

require_relative 'routes/api'

# Peercast Gateway アプリケーションクラス
class Pcgw < Sinatra::Base
  include Logging

  helpers Sinatra::Cookies
  helpers Sinatra::ContentFor
  # delete や patch などのメソッドが使えるようにする
  use Rack::MethodOverride

  NO_NEW_CHANNEL = false

  @@startup_time = Time.now
  @@invoke_count = 0

  configure do
    # The session expires after 30 days.
    use Rack::Session::Cookie, expire_after: 30 * 24 * 3600, same_site: :lax, secret: ENV['CONSUMER_SECRET']
    use Rack::Flash

    # これ無くても動く。
    # OmniAuth::AuthenticityTokenProtection.default_options(key: "csrf.token", authenticity_param: "_csrf")

    # CSRF を防ぐために、POST メソッドで、さらに authenticity_token が必須っぽいので GET はもう使えないっぽい。
    # OmniAuth.config.allowed_request_methods = [:get, :post]

    # これをここに書くと下で omniauth-twitch を設定しても動かない。
    # use OmniAuth::Strategies::Twitch

    use OmniAuth::Builder do
      provider :twitch, ENV['TWITCH_CLIENT_ID'], ENV['TWITCH_CLIENT_SECRET']
      provider :twitter2, ENV["TWITTER_CLIENT_ID"], ENV["TWITTER_CLIENT_SECRET"], callback_path: '/auth/twitter2/callback', scope: "tweet.read users.read"
    end

    use ApiController

    # use Rack::Protection::AuthenticityToken はここに書くとうまく動く。
    use Rack::Protection::AuthenticityToken

    set :cookie_options do
      { expires: Time.now + 30 * 24 * 3600 }
    end

    # 並列実行を禁止する。
    set :lock, true
  end

  configure :development do
    Logging.logger = Logger.new(STDERR)
    Slim::Engine.set_options pretty: true
    set :show_exceptions, :after_handler
    Peercast.logger = Logging.logger
    ActiveRecord::Base.logger = Logging.logger
  end

  configure :production do
    Logging.logger = Logger.new('log/pcgw.log', 'daily')
    Slim::Engine.set_options pretty: false
    Peercast.logger = Logging.logger
    #ActiveRecord::Base.logger = Logging.logger
  end

  def channel_cleanup
    log.info("Channel cleanup start")

    # チャンネルがサーバーで生きているか確認。
    begin
      Channel.all.each do |ch|
        if !ch.exist?
          ch.destroy
          log.error("stale channel entry #{ch.id}(#{ch.gnu_id}) deleted")
        else
          ch.set_status_info!
          if Time.now-(ch.last_active_at || ch.created_at) >= 15.minutes
            ch.servent.api.stopChannel(ch.gnu_id)
            ch.destroy
            log.info("channel #{ch.id}(#{ch.gnu_id}) destroyed for inactivity")
          end
        end
      end
    rescue => e
      log.error(e)
    end

    # サーバーにだけ存在するチャンネルは停止する。
    Servent.enabled.each do |servent|
      servent.api.getChannels.map { |it| it['channelId'] }.each do |cid|
        unless Channel.find_by(gnu_id: cid)
          servent.api.stopChannel(cid)
          log.warn("unknown channel #{cid} on server #{servent.id} stopped")
        end
      end
    end

    log.info("Channel cleanup finished")
  rescue Peercast::Unavailable => e
    log.error("Channel cleanup aborted: #{e.host}:#{e.port} connection error (#{e.message})")
  end

  def ss_cleanup
    Dir.glob("public/ss/*.jpg").each do |path|
      if File.mtime(path) < Time.now - 3600
        FileUtils.rm_f(path)
      end
    end
  end

  before do
    if @@invoke_count%30 == 0
      channel_cleanup
      ss_cleanup
    end
    @@invoke_count += 1

    @noadmin = params['noadmin'] == 'yes'

    # SQLiteに同期をOSに任せるように指定する。
    ActiveRecord::Base.connection.execute('PRAGMA synchronous=OFF')

    @yellow_pages = YellowPage.all

    begin
      get_user
    rescue ActiveRecord::RecordNotFound => e
      log.error("user not found: #{e.to_s}; clearing session")
      session.clear
    end

    # 以下のページはログインしていなくてもアクセスできる。
    # トップページ
    if request.path_info == '/'
      if logged_in?
        redirect to("/home")
      else
        pass
      end
    end
    pass if request.path_info == '/welcome'
    # ヘルプ
    pass if request.path_info =~ %r{^/doc($|/)}
    # プロフィール
    pass if request.path_info =~ %r{^/profile/?}
    # index.txt
    pass if request.path_info == '/index.txt'
    # 配信履歴
    pass if request.path_info =~ %r{^/programs/?}
    # 配信のスクリーンショット
    pass if request.path_info =~ %r{^/ss/}
    # チャンネル一覧、サーバー稼働状況
    pass if request.path_info =~ %r{^/stats}

    # 公開API
    pass if request.path_info =~ %r{^/api/1/}

    pass if request.path_info =~ %r{^/login}

    pass if request.path_info =~ %r{^/auth/}

    if logged_in?
      if @user.suspended
        # 凍結されたアカウントもログアウトはできるようにする。
        pass if request.path_info =~ %r{^/logout$}
        # pass if request.path_info =~ %r{^/account$}

        halt 403, slim(:suspended)
      end

      # 最終ログオン時刻を更新する。
      @user.logged_on_at = Time.now
      @user.save
    else
      # ログインされていなかったらログインフォームページにリダイレクトする。

      redirect to("/login?backref=#{Rack::Utils::escape(request.path)}")
    end
  end

  helpers do
    def oauth
      OAuth::Consumer.new(
        ENV['CONSUMER_KEY'],
        ENV['CONSUMER_SECRET'],
        site: 'https://api.twitter.com',
        schema: :header,
        method: :post,
        request_token_path: '/oauth/request_token',
        access_token_path: '/oauth/access_token',
        authorize_path: '/oauth/authorize')
    end
  end

  get '/auth/twitter' do
    request_token = oauth().get_request_token(oauth_callback: "http://#{request.env['HTTP_HOST']}/auth/twitter/callback")
    session[:token] = request_token.token
    session[:secret] = request_token.secret
    session[:origin] = params['origin']
    redirect request_token.authorize_url
  end

  helpers do
    def my_to_hash(h)
      case h
      when String, Integer, nil, true, false
        h
      when Array
        h.map { |e| my_to_hash(elt) }
      when Enumerable
        h.map { |k,v| [k, my_to_hash(v)] }.to_h
      else
        fail h.class.to_s
      end
    end
  end

  get '/auth/twitch/callback' do
    twitch_user_id = request.env['omniauth.auth']['uid']
    fail unless twitch_user_id =~ /\A\d+\z/

    if logged_in?
      if @user.twitch_id
        if @user.twitch_id != twitch_user_id
          halt 400, "既に別のTwitch User IDが設定されています。"
        else
          # 何もすることはない。
          if request.env['omniauth.origin']
            redirect to("/home")
          else
            redirect to(request.env['omniauth.origin'])
          end
        end
      else
        @user.twitch_id = twitch_user_id
        @user.save!
        flash[:success] = "Twitch のアカウント #{twitch_user_id} と連携しました。"
        if request.env['omniauth.origin'].blank?
          redirect to("/home")
        else
          redirect to(request.env['omniauth.origin'])
        end
      end
    else
      user = User.where(twitch_id: twitch_user_id).first
      if user
        session[:uid] = user.id.to_s

        log.info("user #{user.id} logged in")

        redirect to('/home')
      else
        halt 400, 'Twitchアカウントでの新規ユーザー作成はできません。'
      end
    end        
  end

  after do
    # これやらないと新しく接続できなくなる。
    # ActiveRecord::Base.connection.close

    # メモリを節約。
    if @@invoke_count%10 == 0
      log.info("GC start")
      GC.start
      log.info("GC finished")
    end
  end

  not_found do
    if env["PATH_INFO"].start_with?('/ss/')
      cache_control 'no-cache'
      send_file("public/images/blank_screen.png")
    else
      pass
    end
  end

  error Peercast::Unavailable do
    e = env['sinatra.error']
    servent = Servent.where(hostname: e.host, port: e.port).first
    halt 'servent missing' unless servent

    msg = "servent id #{servent.id} (#{servent.name}) connection error (#{e.message})"
    log.error(msg)
    @message = msg

    [500, {}, erb(:error)]
  end

end

require_relative 'helpers/init'
require_relative 'models/init'
require_relative 'routes/init'
