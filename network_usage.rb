# 帯域使用量計算
class NetworkUsage
  attr_reader :baseline_kbps
  # pcp, TCP 等のオーバーヘッドを加味する
  WITH_OVERHEAD_FACTOR = 1.05

  def initialize(peercast, baseline_kbps)
    @peercast = peercast
    @baseline_kbps = baseline_kbps

    settings = peercast.getSettings
    @maxRelaysPerChannel = settings['maxRelaysPerChannel']
    @maxUpstreamRate = settings['maxUpstreamRate']
  end

  def total_kbps
    raw = @peercast.getChannels.map { |ch|
      bitrate = ch['info']['bitrate']
      bitrate + relay_bandwidth(bitrate)
    }.inject(0, :+)
    (raw * WITH_OVERHEAD_FACTOR).round
  end

  def rate
    total_kbps.fdiv(baseline_kbps)
  end

  private

  # あるチャンネルがリレーに使う最大の帯域
  def relay_bandwidth(channel_bitrate)
    [(@maxUpstreamRate / channel_bitrate), @maxRelaysPerChannel].min * channel_bitrate
  end
end
