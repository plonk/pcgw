class Pcgw < Sinatra::Base
  get '/account' do
    slim :account
  end

  post '/account' do
    @user.update!(params.slice('name'))
    @success_message = '変更を保存しました。'
    slim :account
  end
end
