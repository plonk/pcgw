class Notice < ActiveRecord::Base
  validates_length_of :title, in: 1..30
  validates_length_of :body, in: 1..500

  def render_body
    CGI::escapeHTML(body).gsub("\r\n", '<br>')
  end
end
