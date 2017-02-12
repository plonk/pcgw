require_relative '../jimson'

describe Channel do
  it '所定のインターフェイスを充たす' do
    channel = Channel.new

    expect(channel).to respond_to(:channel_info).with(0).arguments
    expect(channel).to respond_to(:connections).with(0).arguments
    expect(channel).to respond_to(:exist?).with(0).arguments
    expect(channel).to respond_to(:inactive_for).with(0).arguments
    expect(channel).to respond_to(:info).with(0).arguments
    expect(channel).to respond_to(:listener_count_display).with(0).arguments
    expect(channel).to respond_to(:playlist_url).with(0).arguments
    expect(channel).to respond_to(:push_uri).with(0).arguments
    expect(channel).to respond_to(:servent).with(0).arguments
    expect(channel).to respond_to(:source_connection).with(0).arguments
    expect(channel).to respond_to(:status).with(0).arguments
    expect(channel).to respond_to(:stream_key).with(0).arguments
    expect(channel).to respond_to(:stream_url).with(0).arguments
    expect(channel).to respond_to(:user).with(0).arguments
  end

end
