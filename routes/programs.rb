# 配信履歴。「番組情報」

class Pcgw < Sinatra::Base
  get '/programs/?' do
    redirect to "/programs/before/#{Time.now.to_i}/pages/1"
  end

  get '/programs/before/:start/pages/:num' do
    halt(400, 'time not specified') if params['start'].blank?

    start = Time.at(params['start'].to_i)
    num = params['num'].to_i

    programs = ChannelInfo.where('created_at <= ?', start)
      .order(created_at: :desc)

    halt(404, 'data not found') if programs.empty?

    pages = programs.each_slice(10).to_a

    unless num.between?(1, pages.size)
      halt(400, 'page number out of range')
    end

    page = pages[num - 1]
    pagination = OpenStruct.new(first: 1, last: pages.size, current: num)

    slim :programs, locals: {
      programs: page,
      pagination: pagination,
      base_path: "/programs/before/#{params['start']}/pages"
    }
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
