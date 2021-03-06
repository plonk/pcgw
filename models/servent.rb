require 'active_record'
require_relative '../lib/peercast'
require_relative '../lib/logging'

class Servent < ActiveRecord::Base
  has_many :channels
  validates_uniqueness_of :name
  validates_length_of :name, in: 1..30
  validates_length_of :desc, in: 0..100

  include Logging

  def auth_required?
    auth_id.present? || passwd.present?
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
    if boolean
      load_from_server
      save!
    end
    super
  end

  def load_from_server
    self.agent = api.getVersionInfo['agentName']

    supported_yp_uris = api.getYellowPages.map { |yp| yp['announceUri'] || yp['uri'] }

    self.yellow_pages = YellowPage.all.select { |yp|
      supported_yp_uris.include?(yp.uri)
    }.map { |yp| yp.name }.join(' ')
  end

  def can_stop_connections?
    true
  end

  def can_get_relay_tree?
    true
  end

  def can_restart_channel_connection?
    if agent =~ /^PeerCastStation\// then true else false end
  end

  def control_panel_uri
    "http://#{hostname}:#{port}/"
  end

  private

  def create_basic_authorization_header(id, pwd)
    coded = Base64.strict_encode64("#{id}:#{pwd}")
    "BASIC #{coded}"
  end

  class << self
    def request_one(yp)
      enabled.to_a.find { |s| s.yellow_pages.split(' ').include?(yp) && s.vacancies > 0 }
    end

    # すべての有効化されたサーバー。
    def enabled
      Servent.where(enabled: true).order(priority: :asc)
    end

    def total_capacity
      enabled.map { |s| s.max_channels }.inject(0, :+)
    end

  end

end
