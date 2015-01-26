module IndexTxt
  def uptime_fmt(sec)
    min = (sec % 3600) / 60
    hour = sec / 3600
    "%d:%02d" % [hour, min]
  end
  module_function :uptime_fmt

  ESCAPE_TABLE = { '<' => '&lt;', '>' => '&gt;' }
  def field_escape(str)
    str.gsub(/[<>]/) { |ch| ESCAPE_TABLE[ch] }
  end
  module_function :field_escape
end

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
        .join('<>')
    }.join("\n") + "\n"
  end
end
