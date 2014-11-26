# -*- coding: utf-8 -*-
module Jp
  def words(buf)
    wds = []
    loop do
      break if buf.empty?
      case buf
      when /\A\p{Han}+[^\p{Han}\p{Katakana}ー]*/
        w, r = $&, $'
      when /\A[\p{Katakana}ー]+[^\p{Han}\p{Katakana}ー]*/
        w, r = $&, $'
      else
        w, r = buf, ""
      end
      wds << w
      buf = r
    end
    wds
  end
  module_function :words
end
