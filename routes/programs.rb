# 配信履歴。「番組情報」

require_relative '../calendar'
require_relative '../lib/core_ext'

class Pcgw < Sinatra::Base
  get '/programs/?' do
    programs = ChannelInfo.all
    # 配信のあった月と、その月にあった配信の数
    months = programs.flat_map { |pg|
      [:begin, :end].of(pg.time_range).map(&:year_month).uniq
    }.frequencies.sort_by(&:first)
    slim :program_index, locals: { months: months }
  end

  get '/programs/recent' do
    slim :recent_programs
  end

  get '/programs/includes/recent_programs' do
    programs = ChannelInfo.all.order(created_at: :desc).limit(10)
    slim :includes_recent_programs, locals: { programs: programs }, layout: false
  end

  def validate_date(year, month = 1, day = 1)
    Time.new(year, month, day)
    true
  rescue ArgumentError
    false
  end

  get '/programs/by-date/:year/:month' do
    year  = params['year'].to_i
    month = params['month'].to_i
    halt 400, "date not in range" unless validate_date(year, month)

    start = Time.new(year, month)
    programs = ChannelInfo.where('(created_at >= ? AND created_at < ?) OR (terminated_at IS NOT NULL AND terminated_at >= ? AND terminated_at < ?)',
                                 start, start.next(:month),
                                 start, start.next(:month))

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

  get '/programs/:id' do |id|
    program = ChannelInfo.find(id) rescue halt(404, 'entry not found')

    slim :program, locals: { program: program }
  end

  get '/programs/:id/screen_shot' do |id|
    program = ChannelInfo.find(id) rescue halt(404, 'entry not found')
    screen_shot = program.primary_screen_shot
    if screen_shot
      send_file File.expand_path("screen_shots/#{screen_shot.filename}", settings.public_folder)
    else
      redirect to '/images/blank_screen.png'
    end
  end

  get '/programs/:id/screen_shots' do |id|
    program = ChannelInfo.find(id) rescue halt(404, 'entry not found')
    if get_user != program.user
      must_be_admin! @user
    end
    slim :screen_shots, locals: { program: program }
  end

  get '/programs/:id/digest' do |id|
    program = ChannelInfo.find(id) rescue halt(404, 'entry not found')
    begin
      # コンタクトURLがスレだった場合
      if Bbs.shitaraba_thread?(program.url)
        thread = Bbs.thread_from_url(program.url)
        digest = ProgramDigest.new(program, thread.posts(1..Float::INFINITY))
      elsif Bbs.shitaraba_board?(program.url)
        # コンタクトURLが板だった場合
        board = Bbs.board_from_url(program.url)
        threads = board.threads.sort_by(&:created_at)
        # 配信開始よりも前に作成されたスレッドの中で一番新しいもの
        t1 = threads.select { |t| t.created_at < program.created_at }.last

        if program.terminated_at
          termination_time = program.terminated_at.localtime + 5.minutes
        else
          # まだ配信中の場合は現在時刻を範囲の終端にする
          termination_time = Time.now.localtime
        end
        # 配信中に作成されたスレッド
        new_threads = threads.select { |t| t.created_at >= program.created_at && t.created_at < termination_time }

        posts = [*t1, *new_threads].flat_map { |t| t.posts(1..Float::INFINITY) }
        digest = ProgramDigest.new(program, posts)
      else
        halt 404, 'コンタクトURLが掲示板ではありません。'
      end
      slim :program_digest, locals: { program: program, digest: digest }
    rescue Bbs::HTTPError => e
      halt e.code, "掲示板の読み込みができませんでした。エラーコード: #{e.code}"
    end
  end

  delete '/programs/:id' do |id|
    info = ChannelInfo.find(id) rescue halt(404, 'entry not found')

    if get_user != info.user
      must_be_admin! @user
    end

    unless info.terminated_at?
      halt(403, "cannot delete active channel info")
    end
    if info.destroy
      if params[:redirect_path].blank?
        redirect back
      else
        redirect to(params[:redirect_path])
      end
    else
      '失敗しました。'
    end
  end
end
