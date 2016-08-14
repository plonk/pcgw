module TimeUtil
  module Internal
    class << self
      def juxt(*fs)
        -> *args, &block { fs.map { |f| f.(*args, &block) } }
      end

      def contextualize(ref, time)
        tails = ref.zip(time).drop_while { |r,t| r==t }
        tails.map(&:last)
      end
    end
  end

  def date_conv(*ts)
    year        = -> t { "#{t.year}年" }
    month       = -> t { "#{t.month}月" }
    day         = -> t { "#{t.day}日" }
    hour_minute = -> t { " #{t.hour}時#{t.min}分" }

    struct = Internal.juxt(Internal.juxt(year, month, day), hour_minute)

    first, = all = ts.map(&struct)
    rest = all.each_cons(2).map { |(ref_date,_), (date,time)|
      [Internal.contextualize(ref_date, date), time]
    }
    [first, *rest].map { |date, time|
      [date.join, time].join
    }.map(&:strip)
  end
  module_function :date_conv

  def render_time_range(t1, t2)
    date_conv(Time.now, t1, t2).drop(1).join(' 〜 ')
  end
  module_function :render_time_range

  def render_time(time)
    date_conv(Time.now, time).last
  end
  module_function :render_time

  def render_date(t)
    "#{t.month}月#{t.day}日"
  end
  module_function :render_date

  def render_duration(second)
    unless second.is_a?(Integer) then raise TypeError end
    unless second >= 0 then raise ArgumentError end

    hour = second / 3600
    minute = (second % 3600) / 60
    second = second % 60

    fields = [hour, minute, second]
    seen_non_zero = false
    str = ""

    fields.each_with_index do |n, i|
      if n == 0
        if seen_non_zero
        # nothing
        else
          if i == 2
            str += "0秒間"
          else
            # nothing
          end
        end
      else
        str += "#{n}" + ['時', '分', '秒'][i]
        unless seen_non_zero
          str += '間'
          seen_non_zero = true
        end
      end
    end
    return str
  end
  module_function :render_duration
end
