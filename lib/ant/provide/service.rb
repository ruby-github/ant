module Provide
  module Service
    module_function

    def enable name, file, source = nil, arg = nil
      file = File.expand_path file

      if File.file? file
        disable name, file
      end

      if not source.nil?
        if not File.copy_file source, file
          return false
        end

        File.chmod 0755, file
      end

      if OS::name == 'windows'
        if arg.nil?
          arg = file
        else
          arg = [file, arg].utf8.join ' '
        end

        cmdline = 'sc create %s binPath= "%s" start= auto' % [name, arg].utf8
      else
        cmdline = 'systemctl enable %s' % name
      end

      CommandLine::cmdline cmdline do |line, stdin, wait_thr|
        if block_given?
          yield line
        end
      end
    end

    def disable name, file
      if running? name
        stop name
      end

      if File.file? file
        if OS::name == 'windows'
          cmdline = 'sc delete %s' % name
        else
          cmdline = 'systemctl disable %s' % name
        end

        if CommandLine::cmdline cmdline do |line, stdin, wait_thr|
            if block_given?
              yield line
            end
          end

          File.delete_file file

          true
        end
      else
        true
      end
    end

    def start name, expired = nil
      expired ||= 300

      case running?(name)
      when false
        if OS::name == 'windows'
          cmdline = 'sc start %s' % name
        else
          cmdline = 'systemctl start %s' % name
        end

        CommandLine::cmdline cmdline do |line, stdin, wait_thr|
          if block_given?
            yield line
          end
        end

        running = false

        expired.times do
          if running? name
            running = true

            break
          end

          sleep 1
        end

        running
      when true
        true
      else
        nil
      end
    end

    def stop name, expired = nil
      expired ||= 300

      case stopped?(name)
      when false
        if OS::name == 'windows'
          cmdline = 'sc stop %s' % name
        else
          cmdline = 'systemctl stop %s' % name
        end

        CommandLine::cmdline cmdline do |line, stdin, wait_thr|
          if block_given?
            yield line
          end
        end

        stopped = false

        expired.times do
          if stopped? name
            stopped = true

            break
          end

          sleep 1
        end

        stopped
      when true
        true
      else
        true
      end
    end

    def restart name, expired = nil
      stop(name, expired) and start(name, expired)
    end

    def running? name
      case status(name)
      when 'running'
        true
      when nil
        nil
      else
        false
      end
    end

    def stopped? name
      case status(name)
      when 'stopped', 'dead'
        true
      when nil
        nil
      else
        false
      end
    end

    def status name
      state = nil

      if OS::name == 'windows'
        cmdline = 'sc query %s' % name

        CommandLine::cmdline cmdline do |line, stdin, wait_thr|
          if line =~ /STATE\s*:\s*\d+\s+(\w+)/
            state = $1.downcase
          end
        end
      else
        cmdline = 'systemctl status %s' % name

        CommandLine::cmdline cmdline do |line, stdin, wait_thr|
          if line =~ /Active\s*:\s*\w+\s*\((\w+)\)/
            state = $1.downcase
          end
        end
      end

      state
    end
  end
end