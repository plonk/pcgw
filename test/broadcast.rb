require_relative '../jimson'
require_relative '../routes/broadcast'

# info, genre, source_uri, issue

describe PeercastStationBroadcastRequest do
  it '所定のインターフェイスを充たす' do
    req = PeercastStationBroadcastRequest.new(nil, nil, nil, nil)

    expect(req).to respond_to(:info).with(0).arguments
    expect(req).to respond_to(:genre).with(0).arguments
    expect(req).to respond_to(:source_uri).with(0).arguments
    expect(req).to respond_to(:issue).with(0).arguments
  end

  describe 'genre' do
    it 'ChannelInfoのypが空の場合' do
      ch_info = ChannelInfo.new('genre' => 'Game', 'yp' => '')
      req = PeercastStationBroadcastRequest.new(nil, ch_info, nil, nil)

      expect(req.genre).to eq('Game')
    end

    it 'ChannelInfoのypがSPの場合' do
      yellow_pages = YellowPage.all
      ch_info = ChannelInfo.new('genre' => 'Game', 'yp' => 'SP')
      req = PeercastStationBroadcastRequest.new(nil, ch_info, yellow_pages, nil)

      expect(req.genre).to eq('spGame')
    end
  end

  describe 'source_uri' do
    it 'WMV配信の場合' do
      user = User.new('id' => 123)
      ch_info = ChannelInfo.new('stream_type' => 'WMV', 'user' => user)

      req = PeercastStationBroadcastRequest.new(nil, ch_info, nil, nil)
      expect(req.source_uri).to eq("http://#{WM_MIRROR_HOSTNAME}:5000/9123")
    end

    it 'FLV配信の場合' do
      user = User.new('id' => 123)
      ch_info = ChannelInfo.new('stream_type' => 'FLV', 'user' => user)
      servent = Servent.new('hostname' => 'server-name')

      req = PeercastStationBroadcastRequest.new(servent, ch_info, nil, nil)
      expect(req.source_uri).to eq("rtmp://server-name:9123/live/livestream")
    end
  end

  describe 'client_ip' do
    it 'ジャンルの製作者に入る' do
      user = User.new('id' => 123)
      ch_info = ChannelInfo.new('stream_type' => 'FLV', 'user' => user)
      servent = Servent.new('hostname' => 'server-name')

      req = PeercastStationBroadcastRequest.new(servent, ch_info, nil, '123.123.123.123')
      args = req.send(:to_h)
      expect(args[:track][:creator]).to eq('123.123.123.123 via Peercast Gateway')
    end
  end
end

describe PeercastBroadcastRequest do
  it '所定のインターフェイスを充たす' do
    req = PeercastBroadcastRequest.new(nil, nil, nil, nil)

    expect(req).to respond_to(:info).with(0).arguments
    expect(req).to respond_to(:genre).with(0).arguments
    expect(req).to respond_to(:source_uri).with(0).arguments
    expect(req).to respond_to(:issue).with(0).arguments
  end

  describe 'genre' do
    it 'ChannelInfoのypが空の場合' do
      ch_info = ChannelInfo.new('genre' => 'Game', 'yp' => '')
      req = PeercastBroadcastRequest.new(nil, ch_info, nil, nil)

      expect(req.genre).to eq('Game')
    end

    it 'ChannelInfoのypがSPの場合' do
      yellow_pages = YellowPage.all
      ch_info = ChannelInfo.new('genre' => 'Game', 'yp' => 'SP')
      req = PeercastBroadcastRequest.new(nil, ch_info, yellow_pages, nil)

      expect(req.genre).to eq('spGame')
    end
  end

  describe 'source_uri' do
    it 'WMV配信の場合' do
      user = User.new('id' => 123)
      ch_info = ChannelInfo.new('stream_type' => 'WMV', 'user' => user)

      req = PeercastBroadcastRequest.new(nil, ch_info, nil, nil)
      expect(req.source_uri).to eq("http://#{WM_MIRROR_HOSTNAME}:5000/9123")
    end

    it 'FLV配信の場合' do
      user = User.new('id' => 123)
      ch_info = ChannelInfo.new('stream_type' => 'FLV', 'user' => user)
      servent = Servent.new('hostname' => 'server-name')

      req = PeercastBroadcastRequest.new(servent, ch_info, nil, nil)
      # ホスト名 WM_MIRROR_HOSTNAME でいいの？
      expect(req.source_uri).to eq("rtmp://#{WM_MIRROR_HOSTNAME}/live/9123")
    end
  end

end
