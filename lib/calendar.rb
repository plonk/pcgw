# ある月のカレンダー
class Calendar
  attr_reader :year, :month

  def initialize(year, month)
    @year = year
    @month = month
  end

  def weeks
    first_day = Time.new(year, month)
    pre_padding = [nil] * first_day.wday
    last = last_day(year, month)
    post_padding = [nil] * (7 - (Time.new(year, month, last).wday + 1))
    [*pre_padding, *(1..last), *post_padding].each_slice(7).to_a
  end

  private

  def inc_month(y, m)
    if m == 12
      y += 1
      m = 1
    else
      m += 1
    end
    [y, m]
  end

  def last_day(y, m)
    t = Time.new(y, m)
    next_month = Time.new(*inc_month(t.year, t.month))
    (next_month - 1).day
  end
end
