class Pcgw < Sinatra::Base
  get '/doc/?' do
    erb :doc
  end

  DOCS = %w(how-to-obs how-to-wme how-to-ee desc faq repeaters streamlabs)

  get '/doc/:name' do |name|
    halt 404, 'Not Found' unless DOCS.include? name

    erb name.to_sym
  end
end
