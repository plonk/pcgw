class Pcgw < Sinatra::Base
  # ルート。
  get '/' do
    slim :top
  end

  get '/includes/my_channels' do
    slim :my_channels, locals: { channels: @user.channels }, layout: false
  end

  get '/includes/my_history' do
    if params['older_than'].blank?
      older_than = Time.now.to_i + 1
    else
      older_than = Time.at(params['older_than'].to_i)
    end

    if params['user'].blank?
      user = @user
    else
      user = User.find(params['user'].to_i)
      halt 404, 'user not found' unless user
    end

    programs = ChannelInfo.where(user: user)
                 .where('created_at < ?', older_than)
                 .order(created_at: :desc)
                 .limit(15)
    slim :my_history, locals: { recent_programs: programs }, layout: false
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
