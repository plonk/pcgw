class Pcgw < Sinatra::Base
  before '/users/?*' do
    must_be_admin!(@user)
  end

  # ユーザー一覧
  get '/users/?' do
    @users = User.all
    erb :users
  end

  # ユーザー編集画面
  get '/users/:id/edit' do |id|
    @content_user = User.find(id)
    erb :user_edit
  end

  # ユーザー情報を変更
  patch '/users/:id' do |id|
    @content_user = User.find(id)
    @content_user.update!(params.slice('name', 'image', 'admin', 'twitter_id'))
    @content_user.save!
    redirect to("/users/#{@content_user.id}")
  end

  get '/users/:id' do |id|
    @content_user = User.find(id)
    erb :user
  end

  # ユーザーを削除
  delete '/users/:id' do |id|
    @content_user = User.find(id)
    @content_user.destroy!
    erb :delete_user
  end

end
