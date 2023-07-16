require 'json'

class ApiController < Sinatra::Base
  get '/api/1/channelStatus' do
    content_type 'application/json'
    headers "Access-Control-Allow-Origin" => '*'

    halt 400, 'name' if params[:name].blank?

    channels = Channel.all.to_a.select { |ch| ch.channel_info.channel == params[:name] }

    data = channels.map { |ch|
      bitrate_actual = ch.source_connection&.recvRateKbps

      {
        name: ch.channel_info.channel,
        uptime: ch.status['uptime'],
        bitrateOfficial: ch.info['info']['bitrate'],
        bitrateActual: bitrate_actual,
        totalDirects: ch.status['totalDirects'],
        totalRelays: ch.status['totalRelays'],
        description: ch.info['info']['desc'],
        comment: ch.info['info']['comment'],
        genre: ch.info['info']['genre'],
      }
    }

    JSON.dump({ result: data })
  end

  # CSRF トークンを回避する方法がわからないのでPOSTルートが作れない…。
  # post '/api/1/channelStatus' do
  # end
end
