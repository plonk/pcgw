class Pcgw < Sinatra::Base
  # ルート。
  get '/' do
    @channels = Channel.all
    programs = ChannelInfo.all.order(created_at: :desc).limit(10)
    slim :top, locals: { recent_programs: programs }
  end

  # ホーム
  get '/home' do
    @channels = @user.channels
    programs = ChannelInfo.where(user: @user).order(created_at: :desc).limit(10)
    slim :home, locals: { recent_programs: programs }
  end

end
