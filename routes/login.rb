class Pcgw < Sinatra::Base
  # ログイン成功
  get '/auth/twitter/callback' do
    oauth_client = oauth()
    request_token = OAuth::RequestToken.new(oauth_client, session[:token], session[:secret])
    begin
      access_token = oauth_client.get_access_token(request_token, oauth_verifier: params[:oauth_verifier])
    rescue OAuth::Unauthorized
      halt 401, "認証に失敗しました。"
    end
    twitter_client = Twitter::REST::Client.new do |config|
      config.consumer_key = ENV['CONSUMER_KEY']
      config.consumer_secret = ENV['CONSUMER_SECRET']
      config.access_token = access_token.token
      config.access_token_secret = access_token.secret
    end
    twitter_user = twitter_client.user
    name = twitter_user.name
    image_uri = twitter_user.profile_image_uri_https
    twitter_id = twitter_user.id

    origin = session[:origin]

    if session[:uid].blank?
      if (user = User.find_by(twitter_id: twitter_id))
        # ログイン処理。
        # プロフィール画像がローカルではなかったらtwitterと同期する
        unless user.image.start_with?('/')
          user.update!(image: image_uri)
        end
        session[:uid] = user.id.to_s

        log.info("user #{user.id} logged in")

        redirect '/home'
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
