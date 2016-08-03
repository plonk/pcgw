# ビューのデバッグ用ルート。

class Pcgw < Sinatra::Base
  get '/debug/:name' do
    case params['name']
    when 'newuser'
      erb :newuser
    else
      error 'エントリーが定義されていません。'
    end
  end
end
