require_relative '../lib/jp'

class Pcgw < Sinatra::Base
  helpers do
    include ViewHelpers

    # ログインされていたら true。
    def logged_in?
      not session[:uid].blank?
    end

    # 折り返しの制御の為に、日本語のくぎりに零幅空白を挿入する。
    def jp_words(str)
      Jp.words(str).join(ZWSP)
    end
    ZWSP = '&#8203;'

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
      if user.nil? || !user.admin?
        halt 403, 'Administrator only'
      end
    end

    def admin_view?
      if @user.nil?
        false
      elsif !@user.admin?
        false
      elsif @noadmin
        false
      else
        true
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

    def default_to(default_value, value)
      if value.blank?
        default_value
      else
        value
      end
    end

    def auto_link(text)
      text.gsub(/(?:[!#$&-;=\?-\[\]_a-z~]|%[0-9a-fA-F]{2})+/) { |phrase|
        if phrase =~ /^(h?ttps?):\/\/(.*)/ then
          scheme = case $1
                   when 'ttp' then 'http'
                   when 'ttps' then 'https'
                   else $1
                   end
          "<a href=\"#{scheme}://#{$2}\">#{phrase}</a>"
        else
          phrase
        end
      }
    end

    def json_response(data)
      [200, { "Content-Type" => "application/json" }, data.to_json]
    end

    def uptime_fmt(sec)
      min = (sec % 3600) / 60
      hour = sec / 3600
      "%d:%02d" % [hour, min]
    end

  end
end
