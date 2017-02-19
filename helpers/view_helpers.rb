module ViewHelpers
  # (Number, Number) → Number[0.1, 0.9]
  def bitrate_meter(measured_kbps, nominal_kbps)
    # (0, 0) → 0.1
    # (500, 0) → 0.9
    # (0, 500) → 0.1
    # (5000, 500) → 0.9
    if nominal_kbps.zero?
      if measured_kbps.zero?
        return 0.1
      else
        return 0.9
      end
    else
      q = measured_kbps.fdiv(nominal_kbps) / 2.0
      return [[0.1, q].max, 0.9].min
    end
  end
  module_function :bitrate_meter

  def speech_proportion(str)
    str.scan(/\p{Word}/).size.fdiv(str.size)
  end
  module_function :speech_proportion

  def aa?(str)
    if str !~ /<br>/
      false
    else
      # タグっぽいものは削除する
      str = str.gsub(/<[^>]>/, '')
      threshold = 0.7
      speech_proportion(str) < threshold
    end
  end
  module_function :aa?
end
