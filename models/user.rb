require 'active_record'

class User < ActiveRecord::Base
  has_many :channels, dependent: :destroy
  has_many :channel_infos, dependent: :destroy
  has_many :sources, dependent: :destroy
  validates :bio, length: { maximum: 160 }

  def never_broadcast?
    channel_infos.empty?
  end

  def image_https
    if image
      image.sub(/\Ahttp:/, "https:")
    else
      image
    end
  end
end
