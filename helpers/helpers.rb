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

    def default_to(default_value, value)
      if value.blank?
        default_value
      else
        value
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
