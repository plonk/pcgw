require_relative '../lib/bbs_reader'

class Pcgw < Sinatra::Base
  def json_response(data)
    [200, { "Content-Type" => "application/json" }, data.to_json]
  end

  get '/bbs/latest-thread' do
    halt 400, 'Error: board_url key not provided' if params[:board_url].blank?

    board_url = params[:board_url]
    begin
      Timeout.timeout(5) do
        board = Bbs::create_board(board_url)
        settings = board.settings
        if settings.has_key?("ERROR")
          return json_response(
                   {
                     "status"        => "error",
                     "error_message" => settings["ERROR"]
                   }
                 )
        end
        threads = board.threads
        max = settings['BBS_THREAD_STOP']&.to_i || 1000
        livingThreads = threads.select { |t| t.last < max }
        if livingThreads.empty?
          return json_response(
                   {
                     "status"        => "error",
                     "error_message" => "この板には埋まっていないスレッドがありません。"
                   }
                 )
        end
        latestThread = livingThreads.sort_by(&:id).last
        return json_response(
                 {
                   "status" => "ok",
                   "thread_title" => latestThread.title,
                   "last" => latestThread.last,
                   "thread_url" => latestThread.read_url.to_s
                 }
               )
      end
    rescue Timeout::Error
      return json_response(
               {
                 "status"        => "error",
                 "error_message" => "一定時間内に応答を得ることができませんでした。"
               }
             )
    rescue Bbs::Downloader::DownloadFailure
      return json_response(
               {
                 "status"        => "error",
                 "error_message" => "情報を得ることができませんでした。"
               }
             )
    end
  end

  # したらば掲示板の板、あるいはスレッドの情報を代理取得して返す。
  get '/bbs/info' do
    halt 400, 'Error: url key not provided' if params[:url].blank?

    url = params[:url]
    begin
      Timeout.timeout(5) do
        if (thread = Bbs.create_thread(url))
          settings = thread.board.settings
          return json_response(
                   {
                     "status"       => "ok",
                     "type"         => "thread",
                     "title"        => settings['BBS_TITLE'],
                     "thread_title" => thread.title,
                     "last"         => thread.last,
                     "max"          => settings['BBS_THREAD_STOP']&.to_i || 1000,
                     "thread_url"   => thread.read_url.to_s,
                     "board_url"    => thread.board.top_url.to_s,
                   }
                 )
        elsif (board = Bbs.create_board(url))
          # したらばでのエラーチェック。詳細は忘れた。休止機能関連？
          settings = board.settings
          if settings.has_key?("ERROR")
            return json_response(
                     {
                       "status"        => "error",
                       "error_message" => settings["ERROR"]
                     }
                   )
          end

          return json_response(
                   {
                     "status" => "ok",
                     "type"   => "board",
                     "title"  => settings['BBS_TITLE'],
                     "max"    => settings['BBS_THREAD_STOP']&.to_i || 1000,
                     "board_url" => board.top_url.to_s,
                   }
                 )
        else
          return json_response({ "status"        => "error",
                                 "error_message" => "対応している掲示板のURLではありません。" })
        end
      end
    rescue Timeout::Error, Bbs::Downloader::DownloadFailure
      return json_response({ "status"        => "error",
                             "error_message" => "情報を得ることができませんでした。" })
    rescue Bbs::NotFoundError
      return json_response({ "status"        => "error",
                             "error_message" => "そのようなスレはありません。" })
    end
  end
end
