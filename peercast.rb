require 'jimson'

class Peercast
  def initialize(host, port)
    @helper = Jimson::ClientHelper.new("http://#{host}:#{port}/api/1")
  end

  def method_missing(*_args, &block)
    name, *args = _args
    if args.size == 1 and args[0].is_a? Hash
      @helper.process_call(name, *args, &block)
    else
      @helper.process_call(name, args, &block)
    end
  end
end
