require 'net/telnet'

module Net
  class Telnet
    alias __initialize__ initialize
    alias __login__ login
    alias __cmd__ cmd

    def initialize options
      if not options.has_key? 'Prompt'
        if options['windows']
          options['Prompt'] = /C:.*>/
        end
      end

      __initialize__ options
    end

    def login options, password = nil
      __login__ options, password do |c|
        if block_given?
          yield c.utf8
        end
      end
    end

    def cmd options
      __cmd__ options do |c|
        if block_given?
          yield c.utf8
        end
      end
    end

    alias cmdline cmd

    def print string
      if @options['Telnetmode']
        string = string.gsub /#{IAC}/no, IAC + IAC
      end

      if @options['Binmode']
        self.write string
      else
        if @telnet_option['BINARY'] and @telnet_option['SGA']
          self.write string.gsub(/\n/n, CR)
        elsif @telnet_option['SGA']
          self.write string.gsub(/\n/n, EOL)
        else
          self.write string.gsub(/\n/n, EOL)
        end
      end
    end
  end
end

def telnet ip, username, password, windows = true
  begin
    telnet = Net::Telnet::new 'Host' => ip, 'windows' => windows
    telnet.login username, password

    if block_given?
      yield telnet
    end

    telnet.close

    true
  rescue
    LOG_EXCEPTION $!

    false
  end
end