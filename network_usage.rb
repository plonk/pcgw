# 帯域使用量計算
class NetworkUsage
  attr_reader :baseline_kbps
  # pcp, TCP 等のオーバーヘッドを加味する
  WITH_OVERHEAD_FACTOR = 1.05

  def initialize(peercast, baseline_kbps)
    @peercast = peercast
    @baseline_kbps = baseline_kbps

    settings = peercast.getSettings
    @maxRelaysPerChannel = infinityIfZero settings['maxRelaysPerChannel']
    @maxUpstreamRatePerChannel = infinityIfZero settings['maxUpstreamRatePerChannel']
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

  def infinityIfZero(num)
    num==0 ? Float::INFINITY : num
  end

  def numberRelaysByBitrate(channel_bitrate)
    if channel_bitrate == 0
      Float::INFINITY
    else
      @maxUpstreamRatePerChannel / channel_bitrate
    end
  end

  # あるチャンネルがリレーに使う最大の帯域
  def relay_bandwidth(channel_bitrate)
    if channel_bitrate == 0
      0
    else
      [numberRelaysByBitrate(channel_bitrate), @maxRelaysPerChannel].min * channel_bitrate
    end
  end
end
