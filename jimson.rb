# -*- coding: utf-8 -*-
require 'jimson'
require 'sinatra/base'
require_relative 'peercast'
require 'active_support/core_ext'
require 'omniauth-twitter'
require 'active_record'
require_relative 'jp'
require 'sinatra/cookies'
require 'ostruct'
require 'slim'
require_relative 'helpers'
require 'logger'
require_relative 'logging'
require_relative 'network_usage'

# 初期化処理
require_relative 'init'

def peercast
  $peercast ||= Peercast.new(PEERCAST_STATION_PRIVATE_IP, 7144)
end

# Peercast Gateway アプリケーションクラス
class Pcgw < Sinatra::Base
  include Logging

  helpers Sinatra::Cookies
  # delete や patch などのメソッドが使えるようにする
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

  configure :development do
    Logging.logger = Logger.new(STDERR)
    Slim::Engine.set_default_options pretty: true
    Peercast.debug = true
  end

  configure :production do
    Logging.logger = Logger.new('log/pcgw.log', 'daily')
    Slim::Engine.set_default_options pretty: false
  end

  before do
    begin
      @yellow_pages = YellowPage.all
    rescue RestClient::Unauthorized
      halt 500, 'PeerCast Station に認証を要求されました。'
    rescue RestClient::ResourceNotFound
      halt 500, 'PeerCast Station は API による操作を受け付けていません。'
    end
    live_chids = peercast.getChannels.map { |ch| ch['channelId'] }
    Channel.all.each do |ch|
      unless live_chids.include? ch.gnu_id
        ch.destroy
        log.error("stale channel entry #{ch.id}(#{ch.gnu_id}) deleted")
      end
    end
    get_user

    # クッキーを消す
    (cookies.keys - ['rack.session']).each do |key|
      response.delete_cookie(key)
    end

    # /auth/ で始まる URL なら omniauth-twitter に任せる。
    pass if request.path_info =~ %r{^/auth/}

    # 以下のページはログインしていなくてもアクセスできる。
    # トップページ
    pass if request.path_info == '/'
    # ヘルプ
    pass if request.path_info =~ %r{^/doc($|/)}
    # プロフィール
    pass if request.path_info =~ %r{^/profile/}
    # index.txt
    pass if request.path_info == '/index.txt'
    # 配信履歴
    pass if request.path_info == '/programs'

    # ログインされていなかったらログインさせる。
    redirect to('/auth/twitter') unless logged_in?
  end

  after do
    ActiveRecord::Base.connection.close
  end

end

require_relative 'models/init'
require_relative 'routes/init'
