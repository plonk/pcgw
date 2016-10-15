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
    # PecaST 1.9 で入った Cross Site Request Foregeries 対策に適応する
    opts['x-requested-with'] = 'XMLHttpRequest'
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

  def yellow_page_viewer?
    _program_name, version_number = api.getVersionInfo['agentName'].split('/')
    version_number > '1.9.2'
  end

  # YP などの設定
  def setup
    requirement = YellowPage.all
    what_it_has = api.getYellowPages.map { |y| y['name'] }
    shortage = requirement.map(&:name) - what_it_has
    new_signature = yellow_page_viewer?

    shortage.each do |name|
      log.info "adding #{name} to #{self.name}..."
      announceUrl = requirement.find { |y| y.name == name }.uri
      if new_signature
        channelsUrl = ''
        api.addYellowPage('pcp', name, nil, announceUrl, channelsUrl)
      else
        api.addYellowPage('pcp', name, announceUrl)
      end
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
