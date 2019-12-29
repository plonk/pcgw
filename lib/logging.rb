require 'logger'

=begin
ログ取りモジュール

初期化するには Logging.logger に Logger オブジェクトを代入します。

    Logging.logger = Logger.new(STDOUT)

クラスに Logging をインクルードすると、そのクラスのメソッドで Logger オ
ブジェクトを log の名前で使えるようになります。

    class App
      include Logging
      def initialize
        log.info('Application initialized')
      end
      ...

=end
module Logging
  class << self
    attr_accessor :logger
  end

  def log
    fail 'Logging module uninitialized' unless Logging.logger

    Logging.logger
  end
end
