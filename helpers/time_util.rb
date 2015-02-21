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
end
