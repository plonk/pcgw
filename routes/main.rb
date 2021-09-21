class Pcgw < Sinatra::Base
  # ルート。
  get '/' do
    slim :top
  end

  get '/includes/my_channels' do
    slim :my_channels, locals: { channels: @user.channels }, layout: false
  end

  get '/includes/my_history' do
    programs = ChannelInfo.where(user: @user).order(created_at: :desc).limit(10)
    slim :my_history, locals: { recent_programs: programs, user: @user }, layout: false
  end

  # 現在配信中のチャンネルとサーバーの状態
  get '/stats' do
    case params['partial']
    when 'onair'
      erb :includes_onair, locals: { channels: Channel.all }, layout: false
    when 'server_status'
      slim :includes_server_status, locals: { servents: Servent.enabled }, layout: false
    else
      slim :stats, locals: { servents: Servent.enabled }
    end
  end

  # ホーム
  get '/home' do
    programs = ChannelInfo.where(user: @user).order(created_at: :desc).limit(10)
    slim :home, locals: { recent_programs: programs }
  end

end
