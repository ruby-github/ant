require 'drb'

module Ant
  class Daemon
    PORT_COUNT = 100

    def initialize
      @ports = {}
    end

    def close
      @ports.dup.each do |port, use|
        if use
          begin
            drb = DRb::DRbObject.new nil, Mixin::druby(nil, port)
            drb.close

            @ports.delete port
          rescue
          end
        end
      end

      begin
        DRb::stop_service
      rescue
      end

      $errors = nil

      true
    end

    def assign username = nil
      port = nil

      PORT_COUNT.times do |i|
        if not Socket.port_use? 9001 + i
          port = 9001 + i

          break
        end
      end

      if not port.nil?
        cmdline = '%s agent %s' % [Mixin::cmdline('rubyw'), port]

        if OS::user_process cmdline, true, username
          success = false

          60.times do
            begin
              drb = DRb::DRbObject.new nil, Mixin::druby(nil, port)

              if drb.connect?
                success = true

                break
              end
            rescue
            end

            sleep 1
          end

          if success
            @ports[port] = true

            port
          else
            nil
          end
        else
          nil
        end
      else
        nil
      end
    end
  end

  class Agent
    attr_reader :lasterror

    def initialize
      @lasterror = nil
    end

    def close
      begin
        DRb::stop_service
      rescue
      end

      $errors = nil

      true
    end

    def connect?
      true
    end

    def errors
      get_errors
    end

    def loggers
      get_loggers
    end

    def cmdline cmdline, args = nil
      args ||= {}

      home = args[:home]

      if home.nil?
        Provide::CommandLine::cmdline cmdline, args do |line, stdin, wait_thr|
          if block_given?
            yield line
          end
        end
      else
        if File.directory? home
          Dir.chdir home do
            Provide::CommandLine::cmdline cmdline, args do |line, stdin, wait_thr|
              if block_given?
                yield line
              end
            end
          end
        else
          LOG_ERROR 'no such directory: %s' % File.expand_path(home)

          false
        end
      end
    end

    def send_file filename
      filename = filename.locale

      if not File.file? filename
        return false
      end

      begin
        filename = File.expand_path filename

        if not @send_file.nil?
          if @send_file.path != filename
            begin
              @send_file.close
            rescue
            end

            @send_file = nil
          end
        end

        if @send_file.nil?
          @send_file = File.open filename, 'rb'
        end

        data = @send_file.read 4096

        if data.nil?
          @send_file.close
          @send_file = nil
        end

        data
      rescue
        LOG_EXCEPTION $!

        if not @send_file.nil?
          begin
            @send_file.close
          rescue
          end

          @send_file = nil
        end

        false
      end
    end

    def receive_file filename, data
      filename = filename.locale

      begin
        filename = File.expand_path filename

        if not @receive_file.nil?
          if @receive_file.path != filename
            begin
              @receive_file.close
            rescue
            end

            @receive_file = nil
          end
        end

        if @receive_file.nil?
          if not File.mkdir File.dirname(filename)
            return false
          end

          @receive_file = File.open filename, 'wb'
        end

        if data.nil?
          @receive_file.close
          @receive_file = nil
        else
          @receive_file << data
        end

        true
      rescue
        LOG_EXCEPTION $!

        if not @receive_file.nil?
          begin
            @receive_file.close
          rescue
          end

          @receive_file = nil
        end

        false
      end
    end

    def function module_symbol, function_name, *args
      begin
        @lasterror = nil

        module_symbol.__send__ function_name, *args do |*_args_|
          if block_given?
            yield *_args_
          end
        end
      rescue
        @lasterror = $!

        nil
      end
    end
  end

  class Object
    include DRb::DRbUndumped

    attr_reader :drb

    def initialize
      if DRb::thread.nil?
        DRb::start_service Mixin::druby(nil, 0)
      end

      @drb = nil
    end

    def connect ip = nil, port = nil, username = nil
      begin
        daemon = DRb::DRbObject.new nil, Mixin::druby(ip, port)
        port = daemon.assign username

        if not port.nil?
          @drb = DRb::DRbObject.new nil, Mixin::druby(ip, port)

          true
        else
          false
        end
      rescue
        LOG_EXCEPTION $!

        @drb = nil

        false
      end
    end

    def close
      if not @drb.nil?
        begin
          @drb.close
          @drb = nil

          true
        rescue
          false
        end
      else
        true
      end
    end

    def connect?
      begin
        @drb.connect?
      rescue
        false
      end
    end

    def success?
      if @drb.nil?
        true
      else
        begin
          @drb.lasterror.nil?
        rescue
          false
        end
      end
    end

    def loggers
      begin
        @drb.loggers
      rescue
        nil
      end
    end

    def errors
      begin
        @drb.errors
      rescue
        nil
      end
    end

    def cmdline cmdline, args = nil
      begin
        @drb.cmdline cmdline, args do |line|
          if block_given?
            yield line
          end
        end
      rescue
        LOG_EXCEPTION $!

        nil
      end
    end

    def send_file filename, remote_filename
      filename = filename.locale

      if File.file? filename
        begin
          status = true

          File.open filename, 'rb' do |file|
            loop do
              data = file.read 4096

              if not @drb.receive_file remote_filename.utf8, data
                status = false

                break
              end

              if data.nil?
                break
              end
            end
          end

          status
        rescue
          LOG_EXCEPTION $!

          false
        end
      else
        false
      end
    end

    def receive_file filename, remote_filename
      filename = filename.locale

      if not File.mkdir File.dirname(filename)
        return false
      end

      begin
        status = true

        File.open filename, 'wb' do |file|
          loop do
            data = @drb.send_file remote_filename.utf8

            if data.nil?
              break
            else
              if data == false
                status = false

                break
              end

              file << data
            end
          end
        end

        status
      rescue
        LOG_EXCEPTION $!

        false
      end
    end

    def function module_symbol, function_name, *args
      begin
        @drb.function module_symbol, function_name, *args do |*_args_|
          if block_given?
            yield *_args_
          end
        end
      rescue
        LOG_EXCEPTION $!

        nil
      end
    end
  end

  module Mixin
    module_function

    def daemon port = nil
      if OS::name != 'windows'
        pidfile = '/var/run/ruby_daemon.pid'

        if File.directory? File.dirname(pidfile)
          begin
            File.open pidfile, 'w' do |file|
              file.puts Process::pid
            end
          rescue
          end
        end
      end

      service 'ant_daemon', Daemon, port
    end

    def agent port = nil
      service 'ant_agent', Agent, port || 9001
    end

    def service name, klass, port = nil
      begin
        druby = druby '0.0.0.0', port
        daemon = klass.new

        DRb::start_service druby, daemon, nil

        LOG_PUTS COLOR('%s start' % name, COLOR_GREEN, nil, FONT_HIGHLIGHT) + ' ' + druby

        $console = false
        $logging = true

        DRb::thread.join

        true
      rescue Interrupt => e
        true
      rescue
        LOG_EXCEPTION $!

        false
      ensure
        $console = true
        $logging = false

        LOG_PUTS COLOR('%s stop' % name, COLOR_CYAN, nil, FONT_HIGHLIGHT)

        begin
          daemon.close
        rescue
        end
      end
    end

    def cmdline ruby = nil
      if OS::name != 'windows'
        ruby = nil
      end

      '%s %s' % [
        File.cmdline(File.join(RbConfig::CONFIG['bindir'], ruby || 'ruby')),
        File.cmdline(File.join(RbConfig::CONFIG['bindir'], 'ant'))
      ]
    end

    def druby ip = nil, port = nil
      'druby://%s:%s' % [
        ip || Socket.ip_address,
        port || 9000
      ]
    end

    class << self
      private :service
    end
  end
end

at_exit do
  DRb::stop_service
end