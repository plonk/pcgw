require 'active_record'

# チャンネルの作成履歴
class ChannelInfo < ActiveRecord::Base
  belongs_to :user
  has_many :screen_shots, dependent: :destroy

  def primary_screenshot_path
    if hide_screenshots
      "/images/miserarenaiyo.png"
    else
      primary_screen_shot.path
    end
  end

  def primary_screen_shot
    if primary_screen_shot_id
      ScreenShot.find(primary_screen_shot_id)
    else
      latest = screen_shots.order(created_at: :desc).first
      if latest
        if terminated_at
          self.primary_screen_shot_id = latest.id
          save!
          latest
        else
          latest
        end
      else
        ScreenShot.new
      end
    end
  end

  def genre_proper
    Genre.new(genre).proper
  end

  def summary
    if !desc.blank? && !comment.blank?
      "#{desc}。#{comment}"
    else
      [desc, comment, genre_proper, '㊙']
        .find { |field| not field.blank? }
    end
  end

  def time_range
    if terminated_at
      created_at..terminated_at
    else
      created_at..created_at
    end
  end

end
