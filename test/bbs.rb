require_relative '../lib/bbs_reader'

describe Bbs do
  describe 'create_thread' do
    context 'httpで' do
      it 'したらばスレッドを認識する' do
        t = Bbs.create_thread \
                  'http://jbbs.shitaraba.net/bbs/read.cgi/game/48538/1562732337/'
        expect(t).to be_kind_of(Bbs::ThreadBase)
      end

      it 'genkaiスレッドを認識する' do
        t = Bbs.create_thread \
                  'http://genkai.pcgw.pgw.jp/test/read.cgi/shuuraku/1000000000/'
        expect(t).to be_kind_of(Bbs::ThreadBase)
      end

      it 'JPNKNスレッドを認識する' do
        t = Bbs.create_thread \
                  'http://bbs.jpnkn.com/test/read.cgi/yoteichi/1563454793/'
        expect(t).to be_kind_of(Bbs::ThreadBase)
      end

      # Threadオブジェクトを作っただけで何かがダウンロードされる。
    end

    context 'httpsで' do
      it 'したらばスレッドを認識する' do
        t = Bbs.create_thread \
                  'https://jbbs.shitaraba.net/bbs/read.cgi/game/48538/1562732337/'
        expect(t).to be_kind_of(Bbs::ThreadBase)
      end

      it 'genkaiスレッドを認識する' do
        t = Bbs.create_thread \
                  'https://genkai.pcgw.pgw.jp/test/read.cgi/shuuraku/1000000000/'
        expect(t).to be_kind_of(Bbs::ThreadBase)
      end

      it 'JPNKNスレッドを認識する' do
        t = Bbs.create_thread \
                  'https://bbs.jpnkn.com/test/read.cgi/yoteichi/1563454793/'
        expect(t).to be_kind_of(Bbs::ThreadBase)
      end
    end

  end

  describe 'create_board' do
    context 'httpで' do
      it 'したらば板を認識する' do
        expect(Bbs::create_board("http://jbbs.shitaraba.net/game/48538/")).to \
               be_kind_of(Bbs::BoardBase)
      end

      it 'genkai板を認識する' do
        expect(Bbs::create_board("http://genkai.pcgw.pgw.jp/shuuraku/")).to \
               be_kind_of(Bbs::BoardBase)
      end

      it 'JPNKN板を認識する' do
        expect(Bbs::create_board("http://bbs.jpnkn.com/yoteichi/")).to \
               be_kind_of(Bbs::BoardBase)
      end
    end

    context 'httpsで' do
      it 'したらば板を認識する' do
        expect(Bbs::create_board("https://jbbs.shitaraba.net/game/48538/")).to \
               be_kind_of(Bbs::BoardBase)
      end

      it 'genkai板を認識する' do
        expect(Bbs::create_board("https://genkai.pcgw.pgw.jp/shuuraku/")).to \
               be_kind_of(Bbs::BoardBase)
      end

      it 'JPNKN板を認識する' do
        expect(Bbs::create_board("https://bbs.jpnkn.com/yoteichi/")).to \
               be_kind_of(Bbs::BoardBase)
      end
    end

    context 'スレURLで板を作る' do
      it 'したらばスレッドを認識する' do
        t = Bbs.create_board \
                  'http://jbbs.shitaraba.net/bbs/read.cgi/game/48538/1562732337/'
        expect(t).to be_kind_of(Bbs::BoardBase)
      end

      it 'genkaiスレッドを認識する' do
        t = Bbs.create_board \
                  'http://genkai.pcgw.pgw.jp/test/read.cgi/shuuraku/1000000000/'
        expect(t).to be_kind_of(Bbs::BoardBase)
        expect(t).to be_kind_of(Bbs::Nichan::Board)
        expect(t.name).to eq("shuuraku")
      end

      it 'JPNKNスレッドを認識する' do
        t = Bbs.create_board \
                  'http://bbs.jpnkn.com/test/read.cgi/yoteichi/1563454793/'
        expect(t).to be_kind_of(Bbs::BoardBase)
        expect(t).to be_kind_of(Bbs::Nichan::Board)
        expect(t.name).to eq("yoteichi")
      end
    end
  end

  describe Bbs::Shitaraba::Thread do
    it 'read_url' do
      t = Bbs::create_thread('http://genkai.pcgw.pgw.jp/test/read.cgi/shuuraku/1000000000/')
      expect(t.read_url).to be_kind_of(URI)
      expect(t.read_url.to_s).to eq('http://genkai.pcgw.pgw.jp/test/read.cgi/shuuraku/1000000000/')
    end
  end

end
