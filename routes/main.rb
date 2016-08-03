class Pcgw < Sinatra::Base
  # ルート。
  get '/' do
    @channels = Channel.all
    programs = ChannelInfo.all.order(created_at: :desc).limit(10)
    max_channels = Servent.total_capacity
    slim :top, locals: { recent_programs: programs, max_channels: max_channels }
  end

  # ホーム
  get '/home' do
    @channels = @user.channels
    @all_channels = Channel.all
    programs = ChannelInfo.where(user: @user).order(created_at: :desc).limit(10)
    slim :home, locals: { recent_programs: programs, max_channels: Servent.total_capacity }
  end

end
