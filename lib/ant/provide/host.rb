module Provide
  module Host
    module_function

    def hostname hostname
      if OS::name == 'windows'
        begin
          wmi = WIN32OLE.connect 'winmgmts:{impersonationLevel=impersonate}'

          wmi.ExecQuery('SELECT Name FROM Win32_ComputerSystem').each do |object|
            if 0 != object.Rename(hostname)
              return false
            end
          end

          true
        rescue
          LOG_EXCEPTION $!

          false
        end
      else
        file = '/etc/hostname'

        if File.file? file
          begin
            _hostname = IO.read(file).strip

            File.open file, 'w' do |f|
              f.puts hostname
            end

            file = '/etc/hosts'

            if File.file? file
              begin
                lines = []

                IO.readlines(file).each do |line|
                  line = line.rstrip

                  line.gsub! /\s+#{_hostname}(\s+|$)/ do
                    $&.gsub _hostname, hostname
                  end

                  lines << line
                end

                File.open file, 'w' do |f|
                  f.puts lines
                end
              rescue
                LOG_EXCEPTION $!

                false
              end
            end

            true
          rescue
            LOG_EXCEPTION $!

            false
          end
        else
          false
        end
      end
    end

    def network ip, new_ip, subnet_mask, gateway
      if OS::name == 'windows'
        begin
          wmi = WIN32OLE.connect 'winmgmts:{impersonationLevel=impersonate}'

          wmi.ExecQuery('SELECT IPAddress, IPSubnet, DefaultIPGateway FROM Win32_NetworkAdapterConfiguration').each do |object|
            if object.IPAddress.nil?
              next
            end

            if not object.IPAddress.include? ip
              next
            end

            # 0 Successful completion, no reboot required
            # 1 Successful completion, reboot required

            if not [0, 1].include? object.EnableStatic(new_ip.to_array, subnet_mask.to_array)
              return false
            end

            if not [0, 1].include? object.SetGateways(gateway.to_array)
              return false
            end

            break
          end

          true
        rescue
          LOG_EXCEPTION $!

          false
        end
      else
        true
      end
    end

    def remote_network ip, new_ip, subnet_mask, gateway, username = nil, password = nil
      args ||= {}

      if OS::name == 'windows'
        begin
          index = nil

          wmi = WIN32OLE.connect 'winmgmts:{impersonationLevel=impersonate}//%s' % ip

          wmi.ExecQuery('SELECT IPAddress, Index FROM Win32_NetworkAdapterConfiguration').each do |object|
            if object.IPAddress.nil?
              next
            end

            if not object.IPAddress.include? ip
              next
            end

            index = object.Index

            break
          end

          if not index.nil?
            telnet ip, username || 'Administrator', password || 'admin!1234', true do |telnet|
               telnet.cmdline 'wmic NICCONFIG WHERE Index=%s CALL SetGateways(%s), (1)' % [index, gateway] do |c|
                # print c
              end

              begin
                telnet.cmdline 'wmic NICCONFIG WHERE Index=%s CALL EnableStatic(%s), (%s)' % [index, new_ip, subnet_mask] do |c|
                  # print c
                end
              rescue
              end
            end
          else
            false
          end
        rescue
          LOG_EXCEPTION $!

          false
        end
      else
        true
      end
    end

    def dns ip, dns1, dns2 = nil
      dns = [dns1]

      if not dns2.nil?
        dns << dns2
      end

      if OS::name == 'windows'
        begin
          wmi = WIN32OLE.connect 'winmgmts:{impersonationLevel=impersonate}'

          wmi.ExecQuery('SELECT IPAddress, DNSServerSearchOrder FROM Win32_NetworkAdapterConfiguration').each do |object|
            if object.IPAddress.nil?
              next
            end

            if not object.IPAddress.include? ip
              next
            end

            # 0 Successful completion, no reboot required
            # 1 Successful completion, reboot required

            if not [0, 1].include? object.SetDNSServerSearchOrder(dns)
              return false
            end

            break
          end

          true
        rescue
          LOG_EXCEPTION $!

          false
        end
      else
        true
      end
    end

    def shutdown reboot = false
      if OS::name == 'windows'
        begin
          wmi = WIN32OLE.connect 'winmgmts:{impersonationlevel=impersonate,(shutdown)}'

          wmi.ExecQuery('SELECT CSName FROM Win32_OperatingSystem').each do |object|
            # 5 Forced Shutdown (1 + 4)
            # 6 Forced Reboot (2 + 4)

            if reboot
              flags = 6
            else
              flags = 5
            end

            if 0 != object.Win32Shutdown(flags)
              return false
            end

            break
          end

          true
        rescue
          LOG_EXCEPTION $!

          false
        end
      else
        if reboot
          cmdline = 'init 6'
        else
          cmdline = 'init 0'
        end

        CommandLine::cmdline cmdline do |line, stdin, wait_thr|
          if block_given?
            yield line
          end
        end
      end
    end

    def datetime time
      if OS::name == 'windows'
        begin
          wmi = WIN32OLE.connect 'winmgmts:{impersonationLevel=impersonate}'

          wmi.ExecQuery('SELECT CSName FROM Win32_OperatingSystem').each do |object|
            datetime = '%s.%s+%s' % [time.timestamp, ('%06d' % time.usec)[0..5], time.gmt_offset/60]

            if 0 != object.SetDateTime(datetime)
              return false
            end

            break
          end

          true
        rescue
          LOG_EXCEPTION $!

          false
        end
      else
        true
      end
    end
  end
end