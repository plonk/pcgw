# -*- coding: utf-8 -*-
class Pcgw < Sinatra::Base
  helpers do
    # ログインされていたら true
    def logged_in?
      not session[:uid].blank?
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

    def render_date(t, ref = Time.now)
      weekday = [*'㊐㊊㊋㊌㊍㊎㊏'.each_char][t.wday]
      delta = ref - t

      case delta
      when 0...1
        "たった今"
      when 1...(1.minute)
        "#{delta.to_i}秒前"
      when (1.minute)...(1.hour)
        "#{(delta / 60).to_i}分前"
      when (1.hour)...(1.day)
        "#{(delta / 3600).to_i}時間前"
      when (1.day)...(1.month)
        "%d日%s %02d時%02d分" % [t.day, weekday, t.hour, t.min]
      when (1.month)...(1.year)
        "%02d月%02d日%s %02d時%02d分" % \
        [t.year, t.month, t.day, weekday, t.hour, t.min]
      else
        "%04d年%02d月%02d日%s %02d:%02d" % \
        [t.year, t.month, t.day, weekday, t.hour, t.min]
      end
    end

    def status_semantic_class(status)
      case status
      when 'Receiving'
        'text-success'
      when 'Error', 'Searching'
        'text-warning'
      else
        'text-error'
      end
    end

    # Channel モデルに移したほうがよいかも
    def source_stream(channel)
      peercast.getChannelConnections(channel.gnu_id).find { |conn| conn['type'] == 'source' }
    end

    JS_ESCAPE_TABLE = {"\r" => '\r', "\n" => '\n', '"' => '\"' }

    def javascript_string(str)
      '"' + str.gsub(/(\r|\n|")/m) { |c| JS_ESCAPE_TABLE[c] } + '"'
    end

  end
end
