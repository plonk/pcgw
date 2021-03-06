class ProgramDigest
  class Group < Struct.new(:screen_shot, :posts)
  end

  attr_reader :groups

  # (ChannelInfo, [Bbs::Post])
  def initialize(program, posts)
    screen_shots = program.screen_shots
                   .order(created_at: :asc)
                   .to_a

    # 最後のスクリーンショットに対応する時間の範囲の終端
    if program.terminated_at
      termination_time = program.terminated_at.localtime + 5.minutes
    else
      termination_time = Time.now.localtime
    end

    # それぞれのスクリーンショットに対応する時間の範囲
    ranges = [*screen_shots.map { |s| s.created_at.localtime }, termination_time]
             .each_cons(2)
             .map { |t1, t2| t1...t2 }

    @groups = ranges.map.with_index { |range, i|
      ps = posts.select { |post| !post.deleted? && range.cover?(post.datetime) }
      Group.new(screen_shots[i], ps)
    }
  end

end
