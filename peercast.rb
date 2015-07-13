require 'jimson'

class Peercast
  class Unavailable < StandardError
    attr_accessor :host, :port, :message

    def initialize(host, port, message)
      @host, @port, @message = host, port, message
    end
  end

  class << self
    attr_accessor :debug
    Peercast.debug = false
  end

  attr_reader :host, :port

  def initialize(host, port, opts = {})
    @host = host
    @port = port
    @helper = Jimson::ClientHelper.new("http://#{host}:#{port}/api/1", opts)
  end

  def method_missing(*_args, &block)
    name, *args = _args
    value = nil
    span = time do
      value = if args.size == 1 and args[0].is_a? Hash
                @helper.process_call(name, *args, &block)
              else
                @helper.process_call(name, args, &block)
              end
    end
    STDERR.puts("%s: %d msec elapsed" % [name, span*1000]) if Peercast.debug
    value
  rescue Errno::ECONNREFUSED, RestClient::Unauthorized => e
    raise Unavailable.new(host, port, e.message)
  end

  private

  def time(&block)
    start = Time.now
    block.call
    Time.now - start
  end
end
