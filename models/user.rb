require 'active_record'

class User < ActiveRecord::Base
  has_many :channels, dependent: :destroy
  has_many :channel_infos, dependent: :destroy
end
