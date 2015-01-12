require 'jimson'

class Peercast < Jimson::ClientHelper
  def initialize(host, port)
    super("http://#{host}:#{port}/api/1")
  end

  def method_missing(*_args, &block)
    name, *args = _args
    if args.size == 1 and args[0].is_a? Hash
      process_call(name, *args, &block)
    else
      process_call(name, args, &block)
    end
  end

  def has_channel?(name)
    channels = process_call(:getChannels, [])
    channels.any? { |ch| ch['info']['name'] == name }
  end
end
