# coding: utf-8
class Pcgw < Sinatra::Base
  get '/sources' do
    slim :source_index, locals: { sources: @user.sources }
  end

  def generate_unique_key
    alphabet = ('a'..'z').to_a
    while true
      key = alphabet.sample(4).join
      src = Source.find_by(key: key)
      unless src
        break
      end
      log.info('generate_unique_key: collision #{key}')
    end
    return key
  end
  
  get '/sources/add' do
    if @user.sources.count >= 3
      flash[:danger] = "3個以上の追加のソースを作成することはできません。"
      redirect back
    end
    
    name = params['name']
    src = @user.sources.find_by(name: name)
    if src
      flash[:danger] = "その名前の追加のソースは既に存在します。"
      redirect back
    else
      src = @user.sources.build({ name: name, key: generate_unique_key })
      src.save
      flash[:success] = "新しい追加のソースを作成しました。"
      redirect back
    end
  end

  get '/sources/del' do
    id = params['id'].to_i
    src = @user.sources.find(id)
    if src
      src.destroy
      redirect back
    else
      halt 403, "No such source"
    end
  end

  get '/sources/regen' do
    id = params['id'].to_i
    src = @user.sources.find(id)
    if src
      key = generate_unique_key
      src.key = key
      src.save
      redirect back
    else
      halt 403, "No such source"
    end
  end
end
