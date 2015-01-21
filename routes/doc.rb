class Pcgw < Sinatra::Base
  get '/doc/?' do
    erb :doc
  end

  get '/doc/:name' do |name|
    docs = %w(how-to-obs how-to-wme desc)
    halt 404 unless docs.include? name

    erb name.to_sym
  end
end
