class Pcgw < Sinatra::Base
  # ユーザープロフィール
  get '/profile/:id' do |id|
    user = User.find(id) rescue halt(404, 'user not found')
    programs = ChannelInfo.where(user: user).order(created_at: :desc).limit(10)

    slim :profile, locals: { user: user, recent_programs: programs }
  end

  # 対外用ユーザー一覧
  get '/profile' do
    users = User.joins(:channel_infos).distinct.where("logged_on_at >= ?", 30.days.ago).order(:logged_on_at => :desc)
    slim :active_users, locals: { users: users }
  end

end
