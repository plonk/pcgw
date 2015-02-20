require 'ostruct'
require 'resolv'

class RelayTree < OpenStruct
  include Enumerable

  attr_reader :children

  def initialize(hash)
    children = hash.delete('children')
    @children = children.map(&RelayTree.method(:new))
    super(hash)
  end

  def hostname
    Resolv.getname(address)
  rescue
    address
  end

  def endpoint
    "#{anonymize(hostname)}:#{port}"
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

  private

  def anonymize(name)
    _, *xs = name.split('.')
    ['*', *xs].join('.')
  end

end
