require 'twitter'

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
    @content_user.update!(params.slice('name', 'image', 'twitter_id'))
    @content_user.update!(admin: !params['admin'].blank?, suspended: !params['suspended'].blank?)
    @content_user.save!
    redirect to("/users/#{@content_user.id}")
  end

  get '/users/:id' do |id|
    @content_user = User.find(id)
    erb :user
  end

  get '/users/:id/update' do |id|
    content_user = User.find(id) rescue halt(404, 'user not found')
    client = Twitter::REST::Client.new do |config|
      config.consumer_key = ENV['CONSUMER_KEY']
      config.consumer_secret = ENV['CONSUMER_SECRET']
    end
    twitter_user = client.user(content_user.twitter_id)
    content_user.image = twitter_user.profile_image_uri_https(:normal).to_s
    content_user.save!
    redirect to("/users/#{id}")
  end

  # ユーザーを削除
  delete '/users/:id' do |id|
    @content_user = User.find(id)
    @content_user.destroy!
    erb :delete_user
  end

  get '/admin/?' do
    must_be_admin!(@user)
    slim :admin
  end

end
