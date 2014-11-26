def used_ip4_ports
  buf = `/bin/netstat -lnt`
  buf.each_line.drop(2).map(&:split).select { |prot, | p(prot) == "tcp" }.map { |_, _, _, x, | x.split(':').last.to_i }
end

p used_ip4_ports
