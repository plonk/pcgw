require_relative '../lib/nipponize'

class Pcgw < Sinatra::Base
  get '/ip/info/:ip' do
    if params['ip'] =~ /\A(\d+)\.(\d+)\.(\d+)\.(\d+)\z/
      addr = [$1, $2, $3, $4].map(&:to_i)
      unless addr.all? { |n| n >= 0 && n <= 255 } && addr.join('.') == params['ip']
        halt 404, 'not a valid IPv4 address'
      end
    end

    begin
      ip         = params['ip']
      nipponized = Nipponize.encode(ip.split('.').map(&:to_i))
      hostname   = Resolv.getname(ip)
    rescue Resolv::ResolvError
      hostname = 'n/a'
    end

    slim :ip_info, {
           locals: {
             ip: ip,
             nipponized: nipponized,
             hostname: hostname
           }
         }
  end

  get '/ip/decode/:nippongo' do
    begin
      ip = Nipponize.decode(params['nippongo']).join('.')
      redirect to("/ip/info/#{ip}")
    rescue RuntimeError => e
      halt 404, e.message
    end
  end

end
