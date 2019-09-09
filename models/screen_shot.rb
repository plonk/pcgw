require 'active_record'

class ScreenShot < ActiveRecord::Base
  belongs_to :channel_info

  def path
    if filename
      "/screen_shots/#{filename}"
    else
      "/images/blank_screen.png"
    end
  end

  def alt_text
    if filename
      ""
    else
      "[何も映ってない]"
    end
  end
end
