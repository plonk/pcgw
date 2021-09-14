# -*- coding: utf-8 -*-
# アプリケーションの初期化処理

require 'active_record'
require 'yaml'

# 設定ファイルのロード
CONFIG = YAML.load_file('config/config.yml')

# 環境をチェックする
if ENV['PCGW_ENV'].blank?
  puts "PCGW_ENV環境変数を設定して起動してください。(例: PCGW_ENV=production bin/pcgw)"
  exit
end

if ENV['CONSUMER_KEY'].blank?
  puts "警告: CONSUMER_KEY環境変数が設定されていません。"
end

if ENV['CONSUMER_SECRET'].blank?
  puts "警告: CONSUMER_SECRET環境変数が設定されていません。"
end

# DB に接続する
ActiveRecord::Base.establish_connection(CONFIG['db'][ENV['PCGW_ENV']])

WM_MIRROR_HOSTNAME = CONFIG['wm_mirror'][ENV['PCGW_ENV']]['hostname']
PROXY_HOSTNAME = WM_MIRROR_HOSTNAME
