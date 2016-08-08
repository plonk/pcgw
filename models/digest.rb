class ProgramDigest
  class Group < Struct.new(:screen_shot, :posts)
  end

  attr_reader :groups

  # (ChannelInfo, [Bbs::Post])
  def initialize(program, posts)
    screen_shots = program.screen_shots
                   .order(created_at: :asc)
                   .to_a
    ranges = [*screen_shots.map { |s| s.created_at.localtime }, program.terminated_at.localtime].each_cons(2).map { |t1, t2| t1...t2 }

    @groups = ranges.map.with_index { |range, i|
      ps = posts.select { |post| !post.deleted? && range.cover?(post.date) }
      Group.new(screen_shots[i], ps)
    }
  end
  
end
