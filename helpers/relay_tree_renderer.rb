require 'json'
require_relative '../models/relay_tree'
require_relative 'graphviz'

module ColorScheme
  # 基本色名に対し明るい X11 色名を返す。
  def light_shade(basic_color_name)
    case basic_color_name
    when 'red'
      'IndianRed1'
    when 'green'
      'darkolivegreen3'
    when 'blue'
      'skyblue'
    when 'purple'
      'orchid2'
    else
      fail 'unknown color name %p' % basic_color_name
    end
  end

end

class RelayTreeRenderer
  include ColorScheme

  def self.render(root_nodes)
    RelayTreeRenderer.new(root_nodes).render_dot
  end

  def initialize(root_nodes)
    @root_nodes = root_nodes
    @buf = StringIO.new
  end

  def render_dot
    puts 'digraph {'
    puts 'node [fontsize = 10, fontname = "sans-serif"];'

    # 色などの属性値。
    puts '{'
    @root_nodes.each do |r|
      r.each do |n|
        attributes(n)
      end
    end
    puts '}'

    # 辺。
    @root_nodes.each do |r|
      r.each do |n|
        edges(n)
      end
    end

    puts '}'

    @buf.rewind
    @buf.read.tap do
      @buf = StringIO.new
    end
  end

  private

  def edges(node)
    node.children.each do |t|
      puts "%p -> %p" % [node.id, t.id]
    end
  end

  def attributes(t)
    if t.port==7144
      endpoint = anonymize(t.hostname)
    else
      endpoint = "#{anonymize(t.hostname)}:#{t.port}"
    end
    puts "%p [label=%p, style=filled, fillcolor=%p]" % \
    [t.id, endpoint, light_shade(t.color)]
  end

  def puts(*args)
    @buf.puts(*args)
  end

  private

  def anonymize(name)
    _, *xs = name.split('.')
    ['*', *xs].join('.')
  end

end
