module Package
  class Host < Package
    Mixin::package self

    def initialize name
      super name

      @ip = @name
    end

    def ip ip
      @ip = ip
    end

    def hostname hostname, args = nil
      exec :hostname, hostname, args do
        Provide::Host::hostname hostname do |line|
          if block_given?
            yield line
          end
        end
      end
    end

    def network ip, subnet_mask, gateway, args = nil
      exec :network, [ip, subnet_mask, gateway].utf8.join(', '), args do
        if not @ip.nil?
          Provide::Host::network @ip, ip, subnet_mask, gateway do |line|
            if block_given?
              yield line
            end
          end
        else
          false
        end
      end
    end

    def remote_network ip, subnet_mask, gateway, args = nil
      args ||= {}

      exec :remote_network, [ip, subnet_mask, gateway].utf8.join(', '), args do
        if not @ip.nil?
          Provide::Host::remote_network @ip, ip, subnet_mask, gateway,
            username: args[:username], password: args[:password] do |line|
            if block_given?
              yield line
            end
          end
        else
          false
        end
      end
    end

    def dns dns1, dns2 = nil, args = nil
      exec :dns, dns.join(', '), args do
        if not @ip.nil?
          Provide::Host::dns @ip, dns1, dns2 do |line|
            if block_given?
              yield line
            end
          end
        else
          false
        end
      end
    end

    def shutdown reboot = false, args = nil
      exec :shutdown, reboot.to_s, args do
        Provide::Host::shutdown reboot do |line|
          if block_given?
            yield line
          end
        end
      end
    end

    def datetime time, args = nil
      exec :datetime, time.to_s, args do
        Provide::Host::datetime time do |line|
          if block_given?
            yield line
          end
        end
      end
    end
  end
end