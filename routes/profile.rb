class Pcgw < Sinatra::Base
  get '/profile/search' do
    halt 400, 'query must not be blank' if params['query'].blank?

    users = User.where('name like ? escape \'\\\'', params['query'])
    slim :active_users, locals: { users: users, title: '検索結果', query: params['query'] }
  end

  # ユーザープロフィール
  get '/profile/:id' do |id|
    user = User.find(id) rescue halt(404, 'user not found')
    programs = ChannelInfo.where(user: user).order(created_at: :desc).limit(10)

    slim :profile, locals: { user: user, recent_programs: programs }
  end

  # 対外用ユーザー一覧
  get '/profile' do
    users = User.joins(:channel_infos)
            .select('users.*, count(channel_infos.id) as channel_count')
            .group(:id)
            .having("logged_on_at >= ? and channel_count >= 1", Time.now - 30 * 24 * 3600)
            .order(:logged_on_at => :desc)
    slim :active_users, locals: { users: users, title: 'アクティブなユーザー', query: '' }
  end

end
