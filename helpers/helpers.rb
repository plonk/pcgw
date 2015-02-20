# -*- coding: utf-8 -*-
class Pcgw < Sinatra::Base
  helpers do
    # ログインされていたら true。
    def logged_in?
      not session[:uid].blank?
    end

    # 折り返しの制御の為に、日本語のくぎりに零幅空白を挿入する。
    def jp_words(str)
      zwsp = '&#8203;'
      Jp.words(str).join(zwsp)
    end

    # インスタンス変数 @user に現在のユーザーを設定する。
    def get_user
      @user = User.find(session[:uid].to_i) if logged_in?
    end

    # HTML エスケープ略記。
    def h(text)
      Rack::Utils.escape_html(text)
    end

    # ユーザーの属性をバッジで表現する。
    def user_status_raw(user)
      words = []
      words << '<span class=badge>管理者</span>' if user.admin?
      words.join(' ')
    end

    # user が管理者でなければ停止する。
    def must_be_admin!(user)
      halt 403, 'Administrator only' unless user.admin
    end

    # 任意の時刻を文字列表現にする。
    # 24 時間以内は現在からの相対表現で返す。
    def render_date(time, ref = Time.now)
      return 'n/a' unless time

      t = time.localtime

      weekday = [*'㈰㈪㈫㈬㈭㈮㈯'.each_char][t.wday]
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
        [t.month, t.day, weekday, t.hour, t.min]
      else
        "%04d年%02d月%02d日%s %02d:%02d" % \
        [t.year, t.month, t.day, weekday, t.hour, t.min]
      end
    end

    # Peercast Station のチャンネル状態文字列に対応する
    # bootstrap テキストセマンティッククラスを返す。
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

    JS_ESCAPE_TABLE = {"\r" => '\r', "\n" => '\n', '"' => '\"' }

    # str の JavaScript の文字列リテラル表現を返す。
    def javascript_string(str)
      '"' + str.gsub(/(\r|\n|")/m) { |c| JS_ESCAPE_TABLE[c] } + '"'
    end

    # 帯域使用率に対応する bootstrap テキストセマンティッククラスを返す。
    def usage_rate_semantic_class(rate)
      case
      when rate < 1.0
        'text-success'
      when rate < 2.0
        'text-warning'
      else
        'text-danger'
      end
    end

  end
end

module IndexTxt
  def uptime_fmt(sec)
    min = (sec % 3600) / 60
    hour = sec / 3600
    "%d:%02d" % [hour, min]
  end
  module_function :uptime_fmt

  ESCAPE_TABLE = { '<' => '&lt;', '>' => '&gt;' }
  def field_escape(str)
    str.gsub(/[<>]/) { |ch| ESCAPE_TABLE[ch] }
  end
  module_function :field_escape
end
