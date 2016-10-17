require 'rack-flash'

# サーバントの管理
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
        params['id'].each do |id|
          args = SERVENT_ROW_FIELDS.map do |key|
            [key, params["#{key}#{id}"]]
          end.to_h
          args = { 'enabled' => false }.merge args
          servent = Servent.find(id)
          servent.update!(args)
        end
      end
      flash[:success] = '変更は保存されました。'
    rescue => e
      flash[:danger] = "変更の保存に失敗しました。#{e.message}"
    end
    redirect back
  end
  SERVENT_ROW_FIELDS = %w(hostname port max_channels priority enabled).freeze

  post '/servents' do
    args = params.slice('name',
                        'desc',
                        'hostname',
                        'port',
                        'auth_id',
                        'passwd',
                        'max_channels',
                        'priority')
    serv = Servent.new(args)
    serv.save!
    redirect to '/servents'
  end

  patch '/servents/:id' do
    serv = Servent.find(params['id'])
    args = params.slice('name',
                        'desc',
                        'hostname',
                        'port',
                        'auth_id',
                        'passwd',
                        'max_channels',
                        'priority',
                        'enabled')
    args = { 'enabled' => false }.merge args
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
