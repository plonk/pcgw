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
    opts = auth_required? ? { 'authorization' => create_basic_authorization_header(auth_id, passwd) } : {}
    Peercast.new(hostname, port, opts)
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

  private

  def create_basic_authorization_header(id, pwd)
    coded = Base64.strict_encode64("#{id}:#{pwd}")
    "BASIC #{coded}"
  end

  class << self
    def request_one
      enabled.to_a.find { |s| s.vacancies > 0 }
    end

    def enabled
      Servent.where(enabled: true).order(priority: :asc)
    end

    def total_capacity
      enabled.map { |s| s.max_channels }.inject(0, :+)
    end

  end

end
