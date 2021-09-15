require 'active_record'

class User < ActiveRecord::Base
  has_many :channels, dependent: :destroy
  has_many :channel_infos, dependent: :destroy
  has_many :sources, dependent: :destroy
  has_one :password, dependent: :destroy
  validates :bio, length: { maximum: 160 }

  def never_broadcast?
    channel_infos.empty?
  end

  def image_https
    image
  end

  def image_mini
    image.sub(/normal/, 'mini')
  end

  def image_bigger
    image.sub(/normal/, 'bigger')
  end

  def image_200x200
    image.sub(/normal/, '200x200')
  end
end
