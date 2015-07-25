class Pcgw < Sinatra::Base
  # ログイン成功
  get '/auth/twitter/callback' do
    # twitter から取得した名前とアイコンをセッションに設定する。

    if (user = User.find_by(twitter_id: env['omniauth.auth']['uid']))
      # プロフィール画像をtwitterと同期する
      user.update!(image: env['omniauth.auth']['info']['image'])
      session[:uid] = user.id.to_s

      log.info("user #{user.id} logged in")

      redirect env['omniauth.origin']
    else
      user = User.new(name:       env['omniauth.auth']['info']['name'],
                      image:      env['omniauth.auth']['info']['image'],
                      twitter_id: env['omniauth.auth']['uid'])
      user.save
      session[:uid] = user.id.to_s

      log.info("new user #{user.id} signed up")

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
    uid = session[:uid]
    session.clear

    log.info("user #{uid} logged out") unless uid.blank?

    redirect to('/')
  end
end
