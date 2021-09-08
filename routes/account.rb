require 'shellwords'
require 'fileutils'

class Pcgw < Sinatra::Base
  get '/account' do
    slim :account
  end

  helpers do
    def system!(*args)
      cmdline = Shellwords.join(args)
      log.debug("system!: #{cmdline}")
      system(*args) || fail(cmdline)
    end

    def check_magic_number!(path, mime_type)
      case mime_type
      when 'image/png'
        File.open(path, 'rb') do |f|
          head = f.read(8)
          unless head == "\x89PNG\r\n\x1A\n".force_encoding('ASCII-8BIT')
            fail "bad png"
          end
        end
      when 'image/jpeg'
        File.open(path, 'rb') do |f|
          head = f.read(3)
          unless head == "\xFF\xD8\xFF".force_encoding('ASCII-8BIT')
            fail "bad jpeg"
          end
        end
      else
        fail "unsupported MIME type #{mime_type}"
      end
    end

    def save_media(file, mime_type, user_id, prefix)
      ext = case mime_type
            when 'image/png' then '.png'
            when 'image/jpeg' then '.jpg'
            else fail "unsupported MIME type #{mime_type}"
            end

      # 元画像と４つの解像度。
      fn_original = "public/profile_images/#{user_id}/#{prefix}_original#{ext}"
      fn_200x200  = "public/profile_images/#{user_id}/#{prefix}_200x200#{ext}"
      fn_bigger   = "public/profile_images/#{user_id}/#{prefix}_bigger#{ext}"
      fn_normal   = "public/profile_images/#{user_id}/#{prefix}_normal#{ext}"
      fn_mini     = "public/profile_images/#{user_id}/#{prefix}_mini#{ext}"

      FileUtils.mkdir_p("public/profile_images/#{user_id}/")

      open(fn_original, "wb") do |dest|
        IO.copy_stream(file, dest)
      end
      log.info("profile image for #{user_id} saved to #{fn_original}")

      check_magic_number!("public/profile_images/#{user_id}/#{prefix}_original#{ext}", mime_type)

      info = `convert #{fn_original.shellescape} -format "%w %h" info:`
      unless info =~ /\A\d+ \d+\z/
        fail 'failed to get resolution of image (ImageMagick not installed? Note: GraphicsMagic is not really compatible)'
      end
      log.info("image resolution: %s" % info)
      width, height = info.split.map(&:to_i)

      mindim = [width, height].min
      # 正方形にクロップする。元のファイルを置き換える。
      system!('convert', fn_original, '-gravity', 'center', '-crop', "#{mindim}x#{mindim}+0+0", fn_original)

      # その他のサイズにリサイズする。
      system!('convert', fn_original, '-resize', '200x200', fn_200x200)
      system!('convert', fn_original, '-resize', '73x73', fn_bigger)
      system!('convert', fn_original, '-resize', '48x48', fn_normal)
      system!('convert', fn_original, '-resize', '24x24', fn_mini)

      # このユーザー用のディレクトリにあった他のファイル（古い画像セット）を削除する。
      oldfiles = Dir.glob("public/profile_images/#{user_id}/*") - [fn_original, fn_200x200, fn_bigger, fn_normal, fn_mini]
      FileUtils.rm_f(oldfiles)

      # リンクできる相対URLを返す。
      return fn_normal.sub(/^public/, '')
    end
  end

  post '/account' do
    if params['image']
      case params['image']['type']
      when 'image/png', 'image/jpeg'
      else
        halt 400, 'unacceptable mime type'
      end

      prefix = "%04d" % rand(10000)
      begin
        image_path = save_media(params['image']['tempfile'],
                                params['image']['type'],
                                @user.id,
                                prefix)
      rescue => e
        halt 500, "failed to save image: #{e.message}"
      end
      @user.update!(image: image_path)
    end
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
