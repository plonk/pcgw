# 配信履歴。「番組情報」

require_relative '../calendar'

class Pcgw < Sinatra::Base
  # それぞれの要素の数を数える。
  def frequencies(ary)
    itself = -> (x) { x }
    ary.group_by(&itself).map { |key, ary| [key, ary.size] }.to_h
  end

  get '/programs/?' do
    programs = ChannelInfo.all
    months = frequencies(programs.map { |p| c = p.created_at; [c.year, c.month] }).sort_by(&:first)
    slim :program_index, locals: { months: months }
  end

  def validate_date(year, month = 1, day = 1)
    Time.new(year, month, day)
    true
  rescue
    false
  end

  get '/programs/:year/:month' do
    year  = params['year'].to_i
    month = params['month'].to_i
    halt 400, "date not in range" unless validate_date(year, month)

    start = Time.new(year, month)
    next_month = month == 12 ? Time.new(year + 1, 1) : Time.new(year, month + 1)
    programs = ChannelInfo.where('created_at >= ? AND created_at < ?', start, next_month)

    calendar = Calendar.new(year, month)

    slim :program_month, locals: { calendar: calendar, programs: programs }
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
