require 'jimson'
class Peercast < Jimson::ClientHelper
  def initialize(host, port)
    super("http://#{host}:#{port}/api/1")
  end

  def has_channel?(name)
    channels = process_call(:getChannels, [])
    channels.any? { |ch| ch['info']['name'] == name }
  end
end
