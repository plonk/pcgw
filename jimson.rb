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
require_relative 'helpers'

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

  before do
    @yellow_pages = peercast.getYellowPages.map(&OpenStruct.method(:new))
    Channel.all.reject { |ch| ch.exist? }.each { |ch| ch.destroy }
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

    # ログインされていなかったらログインさせる。
    redirect to('/auth/twitter') unless logged_in?
  end

  after do
    ActiveRecord::Base.connection.close
  end

end

require_relative 'routes/init'
