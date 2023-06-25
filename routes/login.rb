class Pcgw < Sinatra::Base
  # ログイン成功
  get '/auth/twitter2/callback' do
    name = request.env['omniauth.auth']['info']['name']
    image_uri = request.env['omniauth.auth']['info']['image']
    twitter_id = request.env['omniauth.auth']['uid']

    # POST /auth/twitter2 に渡した origin パラメーターがここに入ってくる。
    origin = request.env['omniauth.origin']

    if session[:uid].blank?
      if (user = User.find_by(twitter_id: twitter_id))
        # ログイン処理。
        # プロフィール画像がローカルではなかったらtwitterと同期する
        unless user.image.start_with?('/')
          user.update!(image: image_uri)
        end
        session[:uid] = user.id.to_s

        log.info("user #{user.id} logged in")

        if !origin.blank?
          redirect to(origin)
        else
          redirect '/home'
        end
      else
        # サインアップ処理。
        user = User.new(name:       name,
                        image:      image_uri,
                        twitter_id: twitter_id)
        user.save
        session[:uid] = user.id.to_s

        log.info("new user #{user.id} signed up")

        redirect to('/newuser')
      end
    else
      # 既にログインしている状態でTwitterアプリ連携された。
      user = User.find(session[:uid].to_i)
      if user.twitter_id.nil? || user.twitter_id == twitter_id
        user.update!(twitter_id: twitter_id)
        flash[:success] = "Twitter のアカウント #{twitter_id} と連携しました。"
        log.info("user #{user.id}'s twitter id is set to #{twitter_id}")
        

        # プロフィール画像がローカルではなかったらtwitterと同期する
        unless user.image.start_with?('/')
          user.update!(image: image_uri)
        end

        if !origin.blank?
          redirect to(origin)
        else
          redirect '/home'
        end
      else
        # Twitter ID を変える？
        halt 400, "ログアウトしてからやりなおしてください。"
      end
    end
  end

  get '/newuser' do
    erb :newuser
  end

  # ログイン失敗。ユーザーがアプリの認証を拒否した場合。
  # RACK_ENV 環境変数が development でなければ OmniAuth が失敗した時、ここに来る。
  get '/auth/failure' do
    halt 403, "認証できませんでした: #{params[:message]}"
  end

  # ログアウト。セッションをクリアする。
  get '/logout' do
    uid = session[:uid]
    session.clear

    log.info("user #{uid} logged out") unless uid.blank?

    redirect to('/')
  end

  # パスワードログイン。詮索されたくないので、ログインに失敗したときは
  # 同じレスポンスを返すようにする。
  post '/login' do
    halt 400 if params[:user_id].blank? || params[:password].blank?

    if params['backref']&.start_with?('/')
      backref = params['backref']
    else
      backref = nil
    end

    user_id = params[:user_id].to_i
    begin
      user = User.find(user_id)
    rescue ActiveRecord::RecordNotFound
      halt 403, 'Login failed'
    end

    unless user.password
      halt 403, 'Login failed'
    end

    if user.password.validate(params[:password])
      session[:uid] = user_id
      if backref
        redirect to(backref)
      else
        redirect to('/home')
      end
    else
      halt 403, 'Login failed'
    end
  end

  get '/login' do
    slim :login, locals: { backref: params['backref'] }
  end
end
