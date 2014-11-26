# -*- coding: utf-8 -*-
class Pcgw
  helpers do
    # ログインされていたら true
    def current_user
      session[:uid] != nil
    end

    def logged_in?
      current_user
    end

    def jp_words(str)
      zwsp = "&#8203;"
      Jp.words(str).join(zwsp)
    end

    def get_user
      ActiveRecord::Base.connection_pool.with_connection do
        @user = User.find(session[:uid].to_i) if logged_in?
      end
    end

    def source_uri(user)
      port = 9000 + user.id
      "rtmp://#{PEERCAST_STATION_GLOBAL_HOSTNAME}:#{port}/live/livestream"
    end

    def h(text)
      Rack::Utils.escape_html(text)
    end
  end
end
