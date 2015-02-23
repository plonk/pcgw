require 'active_record'

# チャンネルの作成履歴
class ChannelInfo < ActiveRecord::Base
  belongs_to :user

  def genre_proper
    Genre.new(genre).proper
  end

  def summary
    [desc, comment, genre_proper, '㊙']
      .find { |field| not field.blank? }
  end
end
