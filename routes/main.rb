class Pcgw < Sinatra::Base
  # ルート。
  get '/' do
    slim :top
  end

  get '/includes/my_channels' do
    slim :my_channels, locals: { channels: @user.channels }, layout: false
  end

  get '/includes/onair' do
    erb :includes_onair, locals: { channels: Channel.all }, layout: false
  end

  # 現在配信中のチャンネル
  get '/onair' do
    slim :onair
  end

  get '/includes/my_history' do
    programs = ChannelInfo.where(user: @user).where.not(terminated_at: nil).order(created_at: :desc).limit(10)
    slim :my_history, locals: { recent_programs: programs }, layout: false
  end

  get '/includes/channel_switcher' do
    slim :channel_switcher, locals: { channels: @user.channels }, layout: false
  end

  get '/stats' do
    slim :stats, locals: { servents: Servent.enabled }
  end

  # ホーム
  get '/home' do
    slim :home
  end

end
