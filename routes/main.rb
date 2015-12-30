class Pcgw < Sinatra::Base
  # ルート。
  get '/' do
    limit = params['limit'] ? params['limit'].to_i : 10
    limit = [[10, limit].max, 100].min

    @channels = Channel.all
    programs = ChannelInfo.all.order(created_at: :desc).limit(limit)
    max_channels = Servent.total_capacity
    slim :top, locals: { recent_programs: programs, max_channels: max_channels, current_limit: limit, maxed: limit == 100 }
  end

  # ホーム
  get '/home' do
    @channels = @user.channels
    programs = ChannelInfo.where(user: @user).order(created_at: :desc).limit(10)
    slim :home, locals: { recent_programs: programs }
  end


  # チャンネル操作のショートカット
  get '/channel' do
    # チャンネルがまだない場合はチャンネル作成画面へ。
    # チャンネルが1つある場合はチャンネル状態画面へ。
    # チャンネルが複数ある場合はホーム画面へ。(チャンネル一覧があるため)

    case @user.channels.count
    when 0
      redirect to '/create'
    when 1
      redirect to "/channels/#{@user.channels[0].id}"
    else
      redirect to '/home'
    end
  end

end
