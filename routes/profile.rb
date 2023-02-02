class Pcgw < Sinatra::Base
  get '/profile/search' do
    halt 400, 'query must not be blank' if params['query'].blank?

    users = User.where('name like ? escape \'\\\'', params['query'])
    slim :active_users, locals: { users: users, title: '検索結果', query: params['query'] }
  end

  get '/profile/edit' do
    slim :profile_edit, locals: { user: @user }
  end

  post '/profile/edit' do
    if params['image']
      case params['image']['type']
      when 'image/png', 'image/jpeg'
      else
        halt 400, 'unacceptable mime type'
      end

      prefix = "%04d" % rand(10000)
      begin
        image_path = save_media(params['image']['tempfile'],
                                params['image']['type'],
                                @user.id,
                                prefix)
      rescue => e
        halt 500, "failed to save image: #{e.message}"
      end
      @user.update!(image: image_path)
    end
    @user.update!(params.slice('name', 'bio'))
    redirect to("/profile/#{@user.id}")
  end

  # ユーザープロフィール
  get '/profile/:id' do |id|
    user = User.find(id) rescue halt(404, 'user not found')
    programs = ChannelInfo.where(user: user).order(created_at: :desc).limit(10)

    slim :profile, locals: { user: user, recent_programs: programs }
  end

  get '/profile/:id/update' do |id|
    halt 403, 'permission denied' unless @user && @user.id == id.to_i
    content_user = User.find(id) rescue halt(404, 'user not found')
    client = Twitter::REST::Client.new do |config|
      config.consumer_key = ENV['CONSUMER_KEY']
      config.consumer_secret = ENV['CONSUMER_SECRET']
    end
    begin
      twitter_user = client.user(content_user.twitter_id)
    rescue Twitter::Error::NotFound
      halt(404, "Twitter user not found")
    end
    url = twitter_user.profile_image_uri_https(:normal).to_s
    if content_user.image != url
      log.info("Updating profile image for #{content_user.id}: #{content_user.image}")
      content_user.image = twitter_user.profile_image_uri_https(:normal).to_s
      content_user.save!
      log.info("Profile image for #{content_user.id} updated: #{content_user.image}")
    else
      halt(200, "プロフィール画像は最新のようです。")
    end
    redirect back
  end

  # 対外用ユーザー一覧
  get '/profile' do
    users = User.joins(:channel_infos)
            .select('users.*, count(channel_infos.id) as channel_count')
            .group(:id)
            .having("logged_on_at >= ? and channel_count >= 1", Time.now - 30 * 24 * 3600)
            .order(:logged_on_at => :desc)
    # ↑ PostgreSQLだと動かなったかったのだが、下のようなクエリならば動いた。
    # users = User.where("logged_on_at >= ?", Time.now - 30 * 24 * 3600)
    slim :active_users, locals: { users: users, title: 'アクティブなユーザー', query: '' }
  end

  post '/profile/edit/delete-image' do
    if @user.image == "/profile_images/0/0_normal.jpg"
      halt 400, "すでにデフォルト画像です。"
    end
    @user.image = "/profile_images/0/0_normal.jpg"
    @user.save
    redirect back
  end

end
