require 'active_record'

# チャンネルの作成履歴
class ChannelInfo < ActiveRecord::Base
  belongs_to :user

  def summary
    if desc.blank?
      genre
    else
      desc
    end
  end
end
