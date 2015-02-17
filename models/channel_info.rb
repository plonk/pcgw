require 'active_record'

# チャンネルの作成履歴
class ChannelInfo < ActiveRecord::Base
  belongs_to :user

  def summary
    [desc, comment, Genre.new(genre).proper, '㊙']
      .find { |field| not field.blank? }
  end
end
