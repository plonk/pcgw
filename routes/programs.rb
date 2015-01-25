class Pcgw < Sinatra::Base
  get '/programs/?' do
    programs = ChannelInfo.all.order(created_at: :desc)
    slim :programs, locals: { programs: programs }
  end

  delete '/programs/:id' do |id|
    must_be_admin!(@user)

    info = ChannelInfo.find(id) rescue halt(404, 'entry not found')
    if info.destroy
      redirect back
    else
      '失敗しました。'
    end
  end
end
