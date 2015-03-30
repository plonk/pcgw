require 'rack-flash'

class Pcgw < Sinatra::Base
  before '/servents/?*' do
    must_be_admin!(@user)
  end

  # サーバント一覧
  get '/servents/?' do
    servents = Servent.order(priority: :asc)
    slim :servent_index, locals: { servents: servents }
  end

  patch '/servents/all' do
    begin
      Servent.transaction do
        params["id"].each do |id|
          args = {"enabled"=>false}.merge SERVENT_ROW_FIELDS.map { |key| [key, params["#{key}#{id}"]] }.to_h
          servent = Servent.find(id)
          servent.update!(args)
        end
      end
      flash[:success] = "変更は保存されました。"
    rescue => e
      flash[:danger] = "変更の保存に失敗しました。#{e.message}"
    end
    redirect back
  end
  SERVENT_ROW_FIELDS = ['hostname', 'port', 'max_channels', 'priority', 'enabled']      

  post '/servents' do
    args = params.slice('name', 'desc', 'hostname', 'port', 'auth_id', 'passwd', 'max_channels', 'priority')
    serv = Servent.new(args)
    serv.save!
    redirect to '/servents'
  end

  patch '/servents/:id' do
    serv = Servent.find(params['id'])
    args = {'enabled'=>false}.merge params.slice('name', 'desc', 'hostname', 'port', 'auth_id', 'passwd', 'max_channels', 'priority', 'enabled')
    begin
      serv.update!(args)
      flash[:success] = '変更が保存されました。'
    rescue => e
      flash[:danger] = "変更の保存に失敗しました。#{e.message}"
    end
    redirect back
  end

  delete '/servents/:id' do
    serv = Servent.find(params['id'])
    serv.destroy
    redirect back
  end

  get '/servents/:id' do
    servent = Servent.find(params['id'])
    slim :servent, locals: { servent: servent }
  end

end

