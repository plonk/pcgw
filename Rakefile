task :setup do
  system("mkdir -v -p db tmp")
  # Sign in with Twitter ボタンをダウンロードする。
  system("curl -o public/sign-in-with-twitter-gray.png https://cdn.cms-twdigitalassets.com/content/dam/developer-twitter/auth-docs/sign-in-with-twitter-gray.png.twimg.1920.png")
end

task :migrate do
  system("bundle exec ridgepole -c config.yml --apply")
end

task :dryrun do
  system("bundle exec ridgepole -c config.yml --apply --dry-run")
end

task :console do
  system("bundle exec pry -r./models/init -r./lib/bbs_reader.rb -r./lib/core_ext.rb -e \"ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: 'db/pcgw.db'); nil\"")
end

task :dbconsole do
  system("sqlite3 ./db/pcgw.db")
end

task :run do
  system("bundle exec rerun -i '**/*.{slim,erb,js,css}' bundle exec rackup")
end

task :test do
  system("bundle exec rspec test/*.rb")
end
