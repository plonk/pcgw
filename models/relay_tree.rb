require 'ostruct'
require 'resolv'
require 'digest/md5'

class RelayTree < OpenStruct
  include Enumerable

  def initialize(hash)
    hash['children'].map!(&RelayTree.method(:new))
    super(hash)
  end

  def hostname(lookup: true)
    if lookup
      Resolv.getname(address)
    else
      if address =~ /:/
        "[#{address}]"
      else
        address
      end
    end
  rescue
    if address =~ /:/
      "[#{address}]"
    else
      address
    end
  end

  def endpoint(lookup: true)
    "#{hostname(lookup: lookup)}:#{port}"
  end

  def idPort
    addr = hostname(lookup: false)
    "#{Digest::MD5.base64digest(addr.downcase)[0, 8]}:#{port}"
  end

  def id
    "#{address}:#{port}"
  end

  def color
    case
    when isFirewalled
      'red'
    when isRelayFull && localRelays==0
      'purple'
    when isRelayFull && localRelays>0
      'blue'
    when !isRelayFull
      'green'
    else
      fail 'logic error'
    end
  end

  def fertility_count
    count { |c| not c.isRelayFull }
  end

  # 自身とその子孫について block を呼ぶ。
  def each(&block)
    block.(self)
    children.each do |c|
      c.each(&block)
    end
  end

end
