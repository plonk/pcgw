require 'jimson'

class YarrClient < Jimson::Client
  def initialize
    super("http://localhost:8100/")
  end

end
