require 'active_support'
require 'active_support/core_ext'

class Connection
  KEYS = [:connectionId, :type, :status, :sendRate, :recvRate,
          :protocolName, :localRelays, :localDirects, :contentPosition,
          :agentName, :remoteEndPoint, :remoteHostStatus, :remoteName]
  KEYS.each(&method(:attr_accessor))

  def initialize(hash)
    hash.slice(*KEYS.map(&:to_s)).each do |key, val|
      self.send("#{key}=", val)
    end
  end

  def recvRateKbps
    (recvRate * 8 / 1000).round
  end

  def sendRateKbps
    (sendRate * 8 / 1000).round
  end

  def labels
    if remoteHostStatus.include?('relayFull')
      "\u{1f235}" # 「満」の囲み文字
    else
      ''
    end
  end
end
