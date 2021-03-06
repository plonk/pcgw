require 'net/http'
require 'uri'
require 'pp' if $DEBUG

module Bbs

  class NotFoundError < StandardError
  end

  class FormatError < StandardError
  end

  class Post
    class << self
      def from_s(str)
        Post.new(*str.split('<>', 5))
      end
    end

    attr_reader :no, :name, :mail, :body, :date

    def initialize(no, name, mail, date, body)
      @no = no.to_i
      @name = name
      @mail = mail
      @date = date
      @body = body
    end

    def deleted?
      # 四つのフィールドが等しかった場合に削除されたものとみなす。日付以
      # 外のフィールドが日付に等しかった場合、偽陽性となることに注意。
      [@name, @mail, @body].all? { |f| f == @date }
    end

    def to_s
      [no, name, mail, date, body].join('<>')
    end

    def datetime
      str2time(@date)
    end

    private

    def str2time(str)
      if str =~ %r{^(\d{4})/(\d{2})/(\d{2})\(.\) (\d{2}):(\d{2}):(\d{2})}
	y, mon, d, h, min, sec = [$1, $2, $3, $4, $5, $6].map(&:to_i)
	Time.new(y, mon, d, h, min, sec)
      else
        Time.at(0)
	#fail ArgumentError, "Not a date. Delete post? #{str.inspect}"
      end
    end
  end


  class Downloader
    class DownloadFailure < StandardError
      attr_reader :response

      def initialize(response)
        @response = response
      end

      def message
        "#{@response.code} #{@response.message}"
      end
    end

    class Resource
      attr_reader :data

      def initialize(data)
        self.data = data
      end

      def data=(new_data)
        type_check(new_data)
        @data = new_data.dup.freeze
      end

      private

      # ASCII-8BIT エンコーディングの String に限定する。
      def type_check(data)
        unless data.is_a? String
          raise TypeError, 'not a string'
        end
        unless data.encoding == Encoding::ASCII_8BIT
          raise ArgumentError, "encoding not ASCII-8BIT (#{data.encoding})"
        end
      end
    end

    attr_reader :encoding

    def initialize(encoding = 'UTF-8')
      @encoding = encoding
      @resource_cache = {}
    end

    # ASCII-8BIT エンコーディングの文字列を返す。
    def download_binary(uri)
      resource = @resource_cache[uri]
      if resource
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme=='https') do |http|
          request = Net::HTTP::Get.new(uri)
          request['range'] = "bytes=#{resource.data.bytesize}-"
          response = http.request(request)
          response.body.force_encoding('ASCII-8BIT')
          pp response.code if $DEBUG
          pp response.to_hash if $DEBUG
          case response
          when Net::HTTPPartialContent
            p :partial if $DEBUG
            resource.data += response.body
          when Net::HTTPRequestedRangeNotSatisfiable
            p :not_satisfiable if $DEBUG
            # 多分DATは更新されていない
          when Net::HTTPOK
            p :ok if $DEBUG
            @resource_cache[uri] = Resource.new(response.body)
            return response.body
          else
            raise DownloadFailure.new(response)
          end
          return resource.data
        end
      else
        p :no_resource_yet if $DEBUG
        body = download_binary_nocache(uri)
        @resource_cache[uri] = Resource.new(body)
        return body
      end
    end

    def download_binary_nocache(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme=='https') do |http|
        request = Net::HTTP::Get.new(uri)
        response = http.request(request)
        response.body.force_encoding('ASCII-8BIT')
        pp response.code if $DEBUG
        pp response.to_hash if $DEBUG
        case response
        when Net::HTTPOK
        else
          raise DownloadFailure.new(response)
        end
        return response.body
      end
    end

    def download_text(uri)
      # dup は重要。
      download_binary(uri).dup.force_encoding(encoding).encode('UTF-8')
    end
  end

  class BoardBase
    private_class_method :new
    attr_reader :settings_url

    def initialize(text_encoding)
      @downloader = Downloader.new(text_encoding)
    end

    def thread(thread_num)
      threads.find { |t| t.id == thread_num }
    end

    def settings
      return parse_settings(download_text(@settings_url))
    end

    def thread_list
      return download_text(@thread_list_url)
    end

    def dat(thread_num)
      return download_text(dat_url(thread_num))
    end

    def threads
      lines = thread_list.each_line.to_a
      lines.map do |line|
        create_thread_from_line(line)
      end
    end

    # 抽象メソッド
    def create_thread_from_line(_line)
      raise 'unimplemented'
    end

    def dat_url(_thread_num)
      raise 'unimplemented'
    end

    protected

    def download_binary(url)
      @downloader.download_binary(url)
    end

    def download_text(url)
      @downloader.download_text(url)
    end

    def parse_settings(string)
      string.each_line.map { |line|
        pair = line.chomp.split(/=/, 2)
        fail FormatError, 'invalid line' unless pair.size == 2
        fail FormatError, 'invalid key' unless pair[0] =~ /\A\w+\z/
        pair
      }.to_h
    end
  end

  class ThreadBase
    private_class_method :new
    attr_reader :board, :id, :title, :last

    def initialize(board, id, title, last)
      @board = board
      @id = id
      @title = title
      @last = last
    end

    def created_at
      Time.at(id)
    end

    def dat_url
      @board.dat_url(@id)
    end

    def read_url
      @board.read_url(@id)
    end
  end

  module Shitaraba
    SHITARABA_THREAD_URL_PATTERN = %r{\Ahttps?://jbbs\.shitaraba\.net/bbs/read\.cgi/(\w+)/(\d+)/(\d+)(:?|\/.*)\z}
    SHITARABA_BOARD_TOP_URL_PATTERN = %r{\Ahttps?://jbbs\.shitaraba\.net/(\w+)/(\d+)/?\z}

    # したらば板 Bbs::Shitaraba::Board
    class Board < Bbs::BoardBase
      attr_reader :category, :board_num

      class << self
        def from_url(url)
          fail ArgumentError, 'url must be a String' unless url.is_a? String
          if url =~ SHITARABA_BOARD_TOP_URL_PATTERN
            category, board_num = $1, $2.to_i
            return Board.send(:new, category, board_num)
          elsif url =~ SHITARABA_THREAD_URL_PATTERN
            category, board_num, thread_num = $1, $2.to_i, $3.to_i
            return Board.send(:new, category, board_num)
          else
            return nil
          end
        end
      end

      def initialize(category, board_num)
        super('EUC-JP')
        @category = category
        @board_num = board_num
        @settings_url = URI.parse( "http://jbbs.shitaraba.net/bbs/api/setting.cgi/#{category}/#{board_num}/" )
        @thread_list_url = URI.parse( "http://jbbs.shitaraba.net/#{category}/#{board_num}/subject.txt" )
      end

      def dat_url(thread_num)
        URI.parse("http://jbbs.shitaraba.net/bbs/rawmode.cgi/#{@category}/#{@board_num}/#{thread_num}/")
      end

      def read_url(thread_num)
        URI.parse("http://jbbs.shitaraba.net/bbs/read.cgi/#{@category}/#{@board_num}/#{thread_num}/")
      end

      def top_url
        URI.parse("http://jbbs.shitaraba.net/#{@category}/#{@board_num}/")
      end

      def create_thread_from_line(line)
        Thread.from_line(line, self)
      end

      def threads
        ts = super
        if ts.size >= 2
          ts = ts[0..-2] # 最後にトップスレッドが重複している
        end
        return ts
      end

    end

    # したらばスレッド Bbs::Shitaraba::Thread
    class Thread < Bbs::ThreadBase
      class << self
        def from_url(url)
          fail ArgumentError, 'url must be a String' unless url.is_a? String
          if url =~ SHITARABA_THREAD_URL_PATTERN
            category, board_num, thread_num = $1, $2.to_i, $3.to_i
            board = Board.send(:new, category, board_num)
            thread = board.thread(thread_num)
            raise NotFoundError, 'no such thread' if thread.nil?
            return thread
          else
            return nil
          end
        end

        def from_line(line, board)
          unless line =~ /^(\d+)\.cgi,(.+?)\((\d+)\)$/
            fail 'スレ一覧のフォーマットが変です'
          end
          id, title, last = $1.to_i, $2, $3.to_i
          Thread.send(:new, board, id, title, last)
        end
      end

      def initialize(board, id, title, last = 1)
        super
      end

      def posts(range)
        fail ArgumentError unless range.is_a? Range
        dat_for_range(range).each_line.map do |line|
          post = create_post(line.chomp)
          @last = [post.no, last].max
          post
        end
      end

      private

      def create_post(line)
        no, name, mail, date, body, = line.split('<>', 6)
        Post.new(no, name, mail, date, body)
      end

      def dat_for_range(range)
        if range.last == Float::INFINITY
          query = "#{range.first}-"
        else
          query = "#{range.first}-#{range.last}"
        end
        url = URI(dat_url + query)
        @board.send(:download_text, url)
      end
    end
  end # Shitaraba

  module Nichan
    # 2ちゃん板 Bbs::Nichan::Board
    class Board < Bbs::BoardBase
      attr_reader :hostname, :port, :name

      class << self
        def from_url(url)
          fail ArgumentError, 'url must be a String' unless url.is_a? String
          if url =~ NICHAN_THREAD_URL_PATTERN
            board_name = $1
            uri = URI(url)
            uri.path = ""
            return Board.send(:new, uri, board_name)
          else
            uri = URI.parse(url)
            return nil unless uri.scheme == "http" || uri.scheme == "https"
            # 板名に許される文字が何かは知らない。
            if uri.path =~ /\A\/(\w+)\/?/
              board_name = $1
            else
              return nil
            end
            server_uri = uri.dup
            server_uri.path = ""
            return Board.send(:new, server_uri, board_name)
          end
        end
      end

      def initialize(server_uri, name)
        super('CP932')
        @server_uri, @name = server_uri, name

        @settings_url = @server_uri.dup.tap { |u| u.path = "/#{@name}/SETTING.TXT" }
        @thread_list_url = @server_uri.dup.tap { |u| u.path = "/#{@name}/subject.txt" }
      end

      def dat_url(thread_num)
        @server_uri.dup.tap { |u| u.path = "/#{@name}/dat/#{thread_num}.dat" }
      end

      def read_url(thread_num)
        @server_uri.dup.tap { |u| u.path = "/test/read.cgi/#{@name}/#{thread_num}/" }
      end

      def top_url
        @server_uri.dup.tap { |u| u.path = "/#{@name}/" }
      end

      def create_thread_from_line(line)
        Thread.from_line(line, self)
      end
    end

    NICHAN_THREAD_URL_PATTERN = %r{\Ahttps?://[a-zA-z\-\.]+(?::\d+)?/test/read\.cgi\/(\w+)/(\d+)($|/)}

    # 2ちゃんスレッド Bbs::Nichan::Thread
    class Thread < ThreadBase
      class << self
        def from_url(url)
          fail ArgumentError, 'url must be a String' unless url.is_a? String
          if url =~ NICHAN_THREAD_URL_PATTERN
            board_name, thread_num = $1, $2.to_i
            uri = URI(url).tap { |u| u.path = "" }
            board = Board.send(:new, uri, board_name)
            thread = board.thread(thread_num)
            raise NotFoundError, 'no such thread' if thread.nil?
            return thread
          else
            return nil
          end
        end

        def from_line(line, board)
          unless line =~ /^(\d+)\.dat<>(.+?) \((\d+)\)$/
            fail 'スレ一覧のフォーマットが変です'
          end
          id, title, last = $1.to_i, $2, $3.to_i
          Thread.send(:new, board, id, title, last)
        end
      end

      def initialize(board, id, title, last = 1)
        super
      end

      def posts(range)
        fail ArgumentError unless range.is_a? Range
        url = URI(dat_url)
        lines = @board.send(:download_text, url)
        ary = []
        lines.each_line.with_index(1) do |line, res_no|
          next unless range.include?(res_no)

          name, mail, date, body, title = line.chomp.split('<>', 5)
          post = Post.new(res_no.to_s, name, mail, date, body)
          ary << post
          @last = [post.no, last].max
        end
        return ary
      end

    end

  end

  # Bbs.create_board(url) → Shitaraba::Board | Nichan::Board
  # Bbs.create_thread(url) → Shitaraba::Thread | Nichan::Thread

  BOARD_CLASSES = [Shitaraba::Board, Nichan::Board].freeze
  THREAD_CLASSES = [Shitaraba::Thread, Nichan::Thread].freeze

  if $DEBUG
    unless BOARD_CLASSES.all? { |k| k.respond_to?(:from_url) }
      raise 'unmet assumption'
    end

    unless THREAD_CLASSES.all? { |k| k.respond_to?(:from_url) and k.respond_to?(:from_line) }
      raise 'unmet assumption'
    end
  end

  def create_board(url)
    BOARD_CLASSES.each do |klass|
      board = klass.from_url(url)
      return board if board
    end
    return nil
  end
  module_function :create_board

  def create_thread(url)
    THREAD_CLASSES.each do |klass|
      thread = klass.from_url(url)
      return thread if thread
    end
    return nil
  end
  module_function :create_thread

end # Bbs
