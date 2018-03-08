require_relative '../lib/bbs_reader'

class Pcgw < Sinatra::Base
  def json_response(data)
    [200, { "Content-Type" => "application/json" }, data.to_json]
  end

  get '/bbs/latest-thread' do
    halt 400, 'Error: board_num key not provided' if params[:board_num].blank?
    halt 400, 'Error: category key not provided' if params[:category].blank?

    board_num = params[:board_num].to_i
    category = params[:category]
    begin
      Timeout.timeout(5) do
        board = Bbs::Board.new(category, board_num)
        settings = board.settings
        if settings.has_key?("ERROR")
          return json_response({ "status"        => "error",
                                 "error_message" => settings["ERROR"] })
        end
        threads = board.threads
        max = settings['BBS_THREAD_STOP'].to_i
        livingThreads = threads.select { |t| t.last < max }
        if livingThreads.empty?
          return json_response({ "status"        => "error",
                                 "error_message" => "この板には埋まっていないスレッドがありません。" })
        end
        latestThread = livingThreads.sort_by(&:id).last
        return json_response({ "status" => "ok",
                               "thread_title" => latestThread.title,
                               "last" => latestThread.last,
                               "thread_url" => "http://jbbs.shitaraba.net/bbs/read.cgi/#{category}/#{board_num}/#{latestThread.id}/" })
      end
    rescue Timeout::Error, Bbs::HTTPError
      return json_response({ "status"        => "error",
                             "error_message" => "情報を得ることができませんでした。" })
    end
  end

  # したらば掲示板の板、あるいはスレッドの情報を代理取得して返す。
  get '/bbs/info' do
    halt 400, 'Error: url key not provided' if params[:url].blank?

    url = params[:url]
    begin
      Timeout.timeout(5) do
        case url
        when %r{\Ahttps?://jbbs\.shitaraba\.net/bbs/read\.cgi/(\w+)/(\d+)/(\d+)(:?|\/.*)\z}
          category = $1
          board_num = $2.to_i
          thread_num = $3.to_i

          board = Bbs::Board.new(category, board_num)
          settings = board.settings
          if settings.has_key?("ERROR")
            return json_response({ "status"        => "error",
                                   "error_message" => settings["ERROR"] })
          end

          thread = board.thread(thread_num)
          if thread.nil?
            return json_response({ "status"        => "error",
                                   "error_message" => "そのようなスレはありません。" })
          end
          return json_response({ "status"       => "ok",
                                 "type"         => "thread",
                                 "title"        => settings['BBS_TITLE'],
                                 "category"     => category,
                                 "board_num"    => board_num,
                                 "thread_num"    => thread_num,
                                 "thread_title" => thread.title,
                                 "last"         => thread.last,
                                 "max"          => settings['BBS_THREAD_STOP'].to_i })
        when %r{\Ahttps?://jbbs\.shitaraba\.net/(\w+)/(\d+)/?\z}
          category = $1
          board_num = $2.to_i

          board = Bbs::Board.new(category, board_num)
          settings = board.settings
          if settings.has_key?("ERROR")
            return json_response({ "status"        => "error",
                                   "error_message" => settings["ERROR"] })
          end

          return json_response({ "status" => "ok",
                                 "type"   => "board",
                                 "title"  => settings['BBS_TITLE'],
                                 "category" => category,
                                 "board_num" => board_num,
                                 "max"    => settings['BBS_THREAD_STOP'].to_i })
        else
          return json_response({ "status"        => "error",
                                 "error_message" => "したらば掲示板のURLではありません。" })
        end
      end
    rescue Timeout::Error, Bbs::HTTPError
      return json_response({ "status"        => "error",
                             "error_message" => "情報を得ることができませんでした。" })
    end
  end
end
