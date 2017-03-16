require 'open3'

module Provide
  module CommandLine
    module_function

    # args:
    #   async
    #   exitstatus
    #   expired
    #   invisible
    #
    # wait_thr:
    #   async
    def cmdline cmdline, args = nil
      args ||= {}

      if args[:async].is_a? Proc
        async = false
        async_proc = args[:async]
      else
        async = args[:async].to_s.boolean false
        async_proc = nil
      end

      if args[:exitstatus].nil?
        exitstatus = [0]
      else
        exitstatus = args[:exitstatus].to_array
      end

      expired = args[:expired].to_i

      if not args[:invisible]
        if block_given?
          yield LOG_CMDLINE(cmdline, nil), nil, nil
        end
      end

      begin
        stdin, stdout_and_stderr, wait_thr = Open3.popen2e cmdline.locale

        if async
          sleep 1
        end

        begin
          thr = Thread.new do
            str = ''

            loop do
              eof = false

              thread = Thread.new do
                if stdout_and_stderr.eof?
                  if not str.empty?
                    str = str.utf8.rstrip

                    if block_given?
                      begin
                        yield str, stdin, wait_thr
                      rescue Errno::EPIPE => e
                      end
                    end

                    if not async_proc.nil?
                      if async_proc.call str
                        async = true
                      end
                    end

                    str = ''
                  end

                  eof = true
                end
              end

              if thread.join(1).nil?
                if not str.empty?
                  str = str.utf8.rstrip

                  if block_given?
                    begin
                      yield str, stdin, wait_thr
                    rescue Errno::EPIPE => e
                    end
                  end

                  if not async_proc.nil?
                    if async_proc.call str
                      async = true
                    end
                  end

                  str = ''
                end
              end

              thread.join

              if eof
                break
              end

              str << stdout_and_stderr.readpartial(4096)
              lines = str.lines

              str = ''
              wait_thr[:last] = ''

              if lines.last !~ /[\r\n]$/
                wait_thr[:last] = lines.pop.to_s
              end

              lines.each do |line|
                line = line.utf8.rstrip

                if block_given?
                  begin
                    yield line, stdin, wait_thr
                  rescue Errno::EPIPE => e
                  end
                end

                if not async_proc.nil?
                  if async_proc.call str
                    async = true
                  end
                end
              end

              str = wait_thr[:last].to_s
            end
          end

          status = true

          time = Time.now

          loop do
            alive = false

            thr.join 5

            if wait_thr[:async]
              async = true
            end

            if async or not wait_thr.alive?
              thr.exit
            else
              if expired > 0
                if Time.now - time > expired
                  thr.exit

                  LOG_ERROR 'cmdline execute expired: %s' % expired

                  status = nil
                end
              end
            end

            if thr.alive?
              alive = true
            end

            if not alive
              break
            end
          end

          if async
            if not wait_thr.alive?
              if not exitstatus.include? wait_thr.value.exitstatus
                status = false
              end
            end
          else
            begin
              if not exitstatus.include? wait_thr.value.exitstatus
                status = false
              end
            rescue
              LOG_EXCEPTION $!

              status = false
            end
          end

          status
        rescue
          LOG_EXCEPTION $!

          false
        ensure
          if not wait_thr.nil?
            if not wait_thr.alive? or not async
              [stdin, stdout_and_stderr].each do |io|
                if not io.closed?
                  io.close
                end
              end

              wait_thr.join
            end
          end
        end
      rescue
        LOG_EXCEPTION $!

        false
      end
    end
  end
end