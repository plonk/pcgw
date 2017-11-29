# -*- coding: utf-8 -*-
require 'jimson'
require 'sinatra/base'
require 'sinatra/content_for'
require 'active_support'
require 'active_support/core_ext'
require 'omniauth-twitter'
require 'active_record'
require_relative 'jp'
require 'sinatra/cookies'
require 'ostruct'
require 'slim'
require 'logger'
require_relative 'logging'
require_relative 'peercast'
require 'sanitize'

# 初期化処理
require_relative 'init'
require 'rack-flash'

# Peercast Gateway アプリケーションクラス
class Pcgw < Sinatra::Base
  include Logging

  helpers Sinatra::Cookies
  helpers Sinatra::ContentFor
  # delete や patch などのメソッドが使えるようにする
  use Rack::MethodOverride

  NO_NEW_CHANNEL = false

  configure do
    use Rack::Session::Cookie, expire_after: 30.days.to_i, secret: ENV['CONSUMER_SECRET']
    use Rack::Flash

    set :cookie_options do
      { expires: Time.now + 30.days.to_i }
    end

    use OmniAuth::Builder do
      provider :twitter, ENV['CONSUMER_KEY'], ENV['CONSUMER_SECRET']
    end
  end

  configure :development do
    Logging.logger = Logger.new(STDERR)
    Slim::Engine.set_default_options pretty: true
    set :show_exceptions, :after_handler
    Peercast.logger = Logging.logger
    ActiveRecord::Base.logger = Logging.logger
  end

  configure :production do
    Logging.logger = Logger.new('log/pcgw.log', 'daily')
    Slim::Engine.set_default_options pretty: false
    Peercast.logger = Logging.logger
    ActiveRecord::Base.logger = Logging.logger
  end

  before do
    @noadmin = params['noadmin'] == 'yes'

    # SQLiteに同期をOSに任せるように指定する。
    ActiveRecord::Base.connection.execute('PRAGMA synchronous=OFF')

    @yellow_pages = YellowPage.all

    # チャンネルがサーバーで生きているか確認。
    Channel.all.each do |ch|
      if !ch.exist?
        ch.destroy
        log.error("stale channel entry #{ch.id}(#{ch.gnu_id}) deleted")
      elsif ch.inactive_for >= 30.minutes
        ch.servent.api.stopChannel(ch.gnu_id)
        ch.destroy
        log.info("channel #{ch.id}(#{ch.gnu_id}) destroyed for inactivity")
      end
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

    begin
      get_user
    rescue ActiveRecord::RecordNotFound => e
      log.error("user not found: #{e.to_s}; clearing session")
      session.clear
    end

    # クッキーを消す
    (cookies.keys - ['rack.session']).each do |key|
      response.delete_cookie(key)
    end

    # /auth/ で始まる URL なら omniauth-twitter に任せる。
    pass if request.path_info =~ %r{^/auth/}

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
    pass if request.path_info =~ %r{^/channels/\d+/screenshot$}
    # 現在配信中のチャンネル
    pass if request.path_info =~ %r{^/onair$}

    if logged_in?
      # 最終ログオン時刻を更新する。
      @user.logged_on_at = Time.now
      @user.save
    else
      # ログインされていなかったらログインさせる。
      redirect to("/auth/twitter?origin=#{Rack::Utils::escape(env['REQUEST_URI'])}")
    end
  end

  after do
    ActiveRecord::Base.connection.close
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
