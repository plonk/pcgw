require 'ostruct'

class Pcgw < Sinatra::Base
  before '/tests/*' do
    @testing = true
  end

  get '/tests/status' do
    @info = { 'info' => { 'name' => "テストch" } }
    @channel = OpenStruct.new(
      {
        push_uri: "hoge",
        servent: OpenStruct.new(
          {
            name: "fuga",
          }),
        channel_info: OpenStruct.new(
          {
            stream_type: "FLV",
            yp: '平成YP',
          }),
        stream_key: 'abcd',
      })
    @status = { 'uptime' => 0 }
    @bitrate_meter = 0.0
    @yellow_pages = [
      YellowPage.new('平成YP',
                     '',
                     'http://yp.pcgw.pgw.jp/kiyaku.html',
                     'http://yp.pcgw.pgw.jp/',
                     'http://yp.pcgw.pgw.jp/favicon.ico',
                     'pcp://yp.pcgw.pgw.jp:7146/',
                     false)]
    slim :status
  end

end
