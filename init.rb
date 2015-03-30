# -*- coding: utf-8 -*-
require 'active_support'
require 'active_support/core_ext'
require 'active_record'
require 'yaml'

# 設定ファイルのロード
def load_config
  YAML.load_file('config/config.yml')
end

# 環境をチェックする
def check_env
  if ENV['PCGW_ENV'].blank?
    puts "PCGW_ENV環境変数を設定して起動してください。(例: PCGW_ENV=production bin/pcgw)"
    exit
  end

  if ENV['CONSUMER_KEY'].blank? or ENV['CONSUMER_SECRET'].blank?
    puts "CONSUMER_KEY環境変数とCONSUMER_SECRET環境変数を設定して起動してください。"
    exit
  end
end

def pcgw_env
  ENV['PCGW_ENV']
end

# DB に接続
def db_connect
  ActiveRecord::Base.establish_connection(CONFIG['db'][pcgw_env])
end

# アプリケーションの初期化処理
CONFIG = load_config
check_env
db_connect

WM_MIRROR_HOSTNAME = CONFIG['wm_mirror'][pcgw_env]['hostname']
PROXY_HOSTNAME = WM_MIRROR_HOSTNAME
