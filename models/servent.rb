require 'active_record'
require_relative '../peercast'

class Servent < ActiveRecord::Base
  has_many :channels
  validates_uniqueness_of :name
  validates_length_of :name, in: 1..30
  validates_length_of :desc, in: 0..100


  def auth_required?
    auth_id.present? && passwd.present?
  end

  def api
    Peercast.new(hostname, port)
  end

  # 空き枠の数
  def vacancies
    max_channels - channels.size
  end

  class << self
    def request_one
      Servent.order(priority: :asc).to_a.find { |s| s.vacancies > 0 }
    end
  end

end
