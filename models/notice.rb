require 'sanitize'

class Notice < ActiveRecord::Base
  validates_length_of :title, in: 1..60
  validates_length_of :body, in: 1..1000

  def render_body
    Sanitize.fragment(body.gsub("\r\n", '<br>'), Sanitize::Config::RELAXED)
  end
end
