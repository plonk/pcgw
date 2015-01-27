class Pcgw < Sinatra::Base
  get '/doc/?' do
    erb :doc
  end

  get '/doc/:name' do |name|
    docs = %w(how-to-obs how-to-wme desc faq)
    halt 404, 'Not Found' unless docs.include? name

    erb name.to_sym
  end
end
