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
end
