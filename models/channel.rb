class Channel < ActiveRecord::Base
  belongs_to :user

  def status
    @status ||= get_peercast.process_call(:getChannelStatus, [ gnu_id ])
  end

  def info
    @info ||= get_peercast.process_call(:getChannelInfo, [ gnu_id ])
  end

  def exist?
    status
    true
  rescue Jimson::Client::Error
    false
  end
end
