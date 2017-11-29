require 'active_record'

# チャンネルの作成履歴
class ChannelInfo < ActiveRecord::Base
  belongs_to :user
  has_many :screen_shots, dependent: :destroy

  def primary_screen_shot
    if screen_shots.empty?
      ScreenShot.new
    else
      screen_shots.order(created_at: :desc).first
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
