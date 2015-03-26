require 'active_record'
require_relative '../peercast'
require_relative '../logging'

class Servent < ActiveRecord::Base
  has_many :channels
  validates_uniqueness_of :name
  validates_length_of :name, in: 1..30
  validates_length_of :desc, in: 0..100

  include Logging

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

  def enabled=(boolean)
    setup if boolean
    super
  end

  # YP などの設定
  def setup
    requirement = YellowPage.all
    what_it_has = api.getYellowPages.map { |y| y['name'] }

    shortage = requirement.map(&:name) - what_it_has

    shortage.each do |name|
      log.info "adding #{name} to #{self.name}..."
      api.addYellowPage('pcp', name, requirement.find { |y| y.name == name }.uri)
    end

  end

  class << self
    def request_one
      Servent.order(priority: :asc).to_a.find { |s| s.vacancies > 0 }
    end
  end

end
