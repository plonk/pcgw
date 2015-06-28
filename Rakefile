task :setup do
  system("mkdir -v -p db tmp config screenshots")
end

task :migrate do
  system("bundle exec ridgepole -c config.yml --apply")
end

task :dryrun do
  system("bundle exec ridgepole -c config.yml --apply --dry-run")
end

task :console do
  system("pry -r./models/init -e \"ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: 'db/pcgw.db')\"")
end

task :dbconsole do
  system("sqlite3 ./db/pcgw.db")
end

task :run do
   system("rerun -i '**/*.{slim,erb}' bundle exec rackup")
end
