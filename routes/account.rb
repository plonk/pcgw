class Pcgw < Sinatra::Base
  get '/account' do
    slim :account
  end

  post '/account' do
    @user.update!(params.slice('name', 'bio'))
    @success_message = '変更を保存しました。'
    slim :account
  end

  delete '/account/:id' do |id|
    unless @user.id == id.to_i
      halt 403, 'not permitted'
    end

    @user.destroy!
    session.clear
    redirect to("/")
  end
end
