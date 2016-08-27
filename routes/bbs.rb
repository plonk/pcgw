require_relative '../lib/bbs_reader'

class Pcgw < Sinatra::Base
  def json_response(data)
    [200, { "Content-Type" => "application/json" }, data.to_json]
  end

  get '/bbs/info' do
    halt 400, 'Error: url key not provided' if params[:url].blank?

    url = params[:url]
    begin
      Timeout.timeout(3) do 
        case url
        when %r{\Ahttp://jbbs\.shitaraba\.net/bbs/read\.cgi/(\w+)/(\d+)/(\d+)(:?|\/.*)\z}
          category = $1
          board_num = $2.to_i
          thread_num = $3.to_i

          board = Bbs::Board.new(category, board_num)
          settings = board.settings
          if settings.has_key?("ERROR")
            return json_response({ "status"        => "error",
                                   "error_message" => "そのような板はありません。" })
          end

          thread = board.thread(thread_num)
          if thread.nil?
            return json_response({ "status"        => "error",
                                   "error_message" => "そのようなスレはありません。" })
          end
          return json_response({ "status"       => "ok",
                                 "type"         => "thread",
                                 "title"        => settings['BBS_TITLE'],
                                 "thread_title" => thread.title,
                                 "last"         => thread.last,
                                 "max"          => settings['BBS_THREAD_STOP'].to_i })
        when %r{\Ahttp://jbbs\.shitaraba\.net/(\w+)/(\d+)/?\z}
          category = $1
          board_num = $2.to_i

          board = Bbs::Board.new(category, board_num)
          settings = board.settings
          if settings.has_key?("ERROR")
            return json_response({ "status"        => "error",
                                   "error_message" => "そのような板はありません。" })
          end

          return json_response({ "status" => "ok",
                                 "type"   => "board",
                                 "title"  => settings['BBS_TITLE'],
                                 "max"    => settings['BBS_THREAD_STOP'].to_i })
        else
          return json_response({ "status"        => "error",
                                 "error_message" => "したらば掲示板のURLではありません。" })
        end
      end
    rescue Timeout::Error
      return json_response({ "status"        => "error",
                             "error_message" => "情報を得ることができませんでした。" })
    end
  end
  
end
