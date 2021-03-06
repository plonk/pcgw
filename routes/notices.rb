class Pcgw < Sinatra::Base
  get '/notices/?' do
    @user.notice_checked_at = Time.now
    @user.save
    slim :notice_index, locals: { notices: Notice.all.order(created_at: :desc) }
  end

  get '/notices/new' do
    must_be_admin!(@user)

    slim :notice_form, locals: { notice: Notice.new }
  end

  get '/notices/:id' do |id|
    slim :notice_view, locals: { notice: Notice.find(id) }
  end

  delete '/notices/:id' do |id|
    notice = Notice.find(id)
    notice.destroy!
    redirect to '/notices'
  end

  get '/notices/:id/edit' do |id|
    must_be_admin!(@user)

    slim :notice_edit, locals: { notice: Notice.find(id) }
  end

  patch '/notices/:id' do |id|
    notice = Notice.find(id)
    notice.update! params.slice('body', 'title')
    redirect to "/notices/#{notice.id}"
  end

  post '/notices/?' do
    notice = Notice.new(params.slice('body', 'title'))
    notice.save!
    redirect to "/notices/#{notice.id}"
  end
end
