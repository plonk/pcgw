class Channel < ActiveRecord::Base
  belongs_to :user

  def status
    @status ||= peercast.getChannelStatus(gnu_id)
  end

  def info
    @info ||= peercast.getChannelInfo(gnu_id)
  end

  def exist?
    status
    true
  rescue Jimson::Client::Error
    false
  end
end
