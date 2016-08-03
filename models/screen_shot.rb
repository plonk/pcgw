require 'active_record'

class ScreenShot < ActiveRecord::Base
  belongs_to :channel_info
end
