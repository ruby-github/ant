require 'socket'

class Socket
  def self.ip_addresses
    ips = []

    Socket.ip_address_list.each do |address|
      if address.ipv4_private?
        ips << address.ip_address
      end
    end

    if ips.empty?
      ips << '127.0.0.1'
    end

    ips.sort!
    ips.uniq!

    ips
  end

  def self.ip_address ignores = nil
    ips = ip_addresses
    first = ips.first

    if ips.size > 1
      ignores ||= '192.'

      ips.delete_if do |ip|
        del = false

        ignores.to_array.each do |ignore|
          if ip.start_with? ignore
            del = true
          end
        end

        del
      end
    end

    ips.first || first
  end

  def self.port_use? port, ip = nil
    if ip.nil?
      ips = ip_addresses
    else
      ips = [ip]
    end

    ips.each do |ip|
      begin
        socket = Socket.new Socket::AF_INET, Socket::SOCK_STREAM, 0
        socket.connect Socket.pack_sockaddr_in(port, ip)
        socket.close

        return true
      rescue
      end
    end

    false
  end
end