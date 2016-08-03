class Pcgw < Sinatra::Base
  get '/screen_shots/:filename' do |filename|
    path = "screenshots/#{filename}"
    unless File.exist? path
      halt 404
    end
    unless File.readable? path
      halt 403
    end

    return [200, { 'Content-Type' => 'image/jpeg' }, File.read("screenshots/#{filename}")]
  end
end
