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
      zwsp = '&#8203;'
      Jp.words(str).join(zwsp)
    end

    def get_user
      @user = User.find(session[:uid].to_i) if logged_in?
    end

    def source_uri_rtmp(user)
      port = 9000 + user.id
      "rtmp://#{PEERCAST_STATION_GLOBAL_HOSTNAME}:#{port}/live/livestream"
    end

    def source_uri_http(user)
      path = "#{9000 + user.id}"
      "http://#{WM_MIRROR_HOSTNAME}:5000/#{path}"
    end

    def h(text)
      Rack::Utils.escape_html(text)
    end

    def user_status_raw(user)
      words = []
      words << '<span class=badge>管理者</span>' if user.admin?
      words.join(' ')
    end

    def must_be_admin!(user)
      halt 403, 'Administrator only' unless user.admin
    end

    def yellow_page_links(yps)
      yps.map do |yp|
        "<a href=\"#{h yellow_page_home(yp['name'])}\">" \
        "#{h yp['name']}</a>"
      end.join(', ')
    end

    # Data as code!
    def yellow_page_home(name)
      case name
      when 'SP'
        'http://bayonet.ddo.jp/sp/'
      when 'TP'
        'http://temp.orz.hm/yp/'
      else
        ''
      end
    end
  end
end
