class Pcgw < Sinatra::Base
  # ログイン成功
  get '/auth/twitter/callback' do
    # twitter から取得した名前とアイコンをセッションに設定する。

    if (user = User.find_by(twitter_id: env['omniauth.auth']['uid']))
      user.update!(image: env['omniauth.auth']['info']['image'])
      session[:uid] = user.id.to_s
      redirect '/home'
    else
      user = User.new(name:       env['omniauth.auth']['info']['name'],
                      image:      env['omniauth.auth']['info']['image'],
                      twitter_id: env['omniauth.auth']['uid'])
      user.save
      session[:uid] = user.id.to_s

      redirect to('/newuser')
    end
  end

  get '/newuser' do
    erb :newuser
  end

  # ログイン失敗。ユーザーがアプリの認証を拒否した場合。
  get '/auth/failure' do
    '認証できませんでした'
  end

  # ログアウト。セッションをクリアする。
  get '/logout' do
    session.clear
    redirect to('/')
  end
end
