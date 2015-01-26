require 'logger'

module Logging
  class << self
    attr_accessor :logger
  end

  def log
    fail 'Logging module uninitialized' unless Logging.logger

    Logging.logger
  end
end
