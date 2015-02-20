module Graphviz
  def dot(dot, format: 'svg')
    IO.popen("dot -T#{format}", 'r+') do |pipe|
      pipe.write(dot)
      pipe.close_write
      pipe.read.each_line.drop(3).join # doctype 宣言を削る。
    end
  end
  module_function :dot

end
