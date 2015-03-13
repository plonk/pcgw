# モンキーパッチ

class Object
  object = Object.new

  # 2.2 で導入された itself メソッド
  def itself
    self
  end unless object.respond_to?(:itself)

end

class Array
  # それぞれの要素の数を数える。
  def frequencies
    group_by(&:itself).map { |k,ary| [k, ary.size] }.to_h
  end

  def of(obj)
    fs = map(&:to_proc)
    fs.map { |f| f.(obj) }
  end

end

class Time
  def year_month
    [year, month]
  end

  # その単位の初めからちょうど1進ませる秒数
  UNITS = {
    year:  366 * 24 * 3600,
    month:  31 * 24 * 3600,
    day:         24 * 3600,
    hour:             3600,
    min:                60,
    sec:                 1,
  }

  def next(unit)
    raise ArgumentError, "unknown unit of time" unless UNITS.has_key?(unit)

    (self.start_of(unit) + UNITS[unit]).start_of(unit)
  end

  def start_of(unit)
    raise ArgumentError, "unknown unit of time" unless UNITS.has_key?(unit)

    names = UNITS.each_key.slice_after { |k| k == unit }.first
    Time.new(*names.map(&self.method(:send)))
  end

end

module Enumerable
  # 2.2 compatibility
  def slice_after(pattern = nil, &block)
    pred = pattern ? pattern.method(:===) : block

    Enumerator.new do |yielder|
      buf = []
      lazy.zip(lazy.map(&pred)).each do |elt, test|
        if test
          yielder << (buf << elt)
          buf = []
        else
          buf << elt
        end
      end
      yielder << buf unless buf.empty?
    end
  end unless Enumerable.instance_methods.include?(:slice_after)

end
