# -*- coding: utf-8 -*-
class Pcgw
  # YP4G 互換の index.txt
  get '/index.txt' do
    endpoint = peercast.getStatus['globalRelayEndPoint'].join(':')

    Channel.all.map { |ch|
      i = ch.info['info']
      uptime = ch.status['uptime']
      s = ch.status

      [i['name'],ch.gnu_id,endpoint,i['url'],i['genre'],i['desc'],
       s['totalDirects'],s['totalRelays'],i['bitrate'],i['contentType'],
       '','','','',
       URI.encode(i['name']),IndexTxt.uptime_fmt(s['uptime']),'click',i['comment'],"0"]
        .map(&:to_s).map(&IndexTxt.method(:field_escape))
        .join('<>') + "\n"
    }.join
  end
end
