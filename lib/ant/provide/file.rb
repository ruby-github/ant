module Provide
  class File < ::File
    def self.send ip, source, file, username = nil
      drb_connect ip, username do |drb|
        case
        when File.file?(source)
          if not drb.function File, :directory?, file
            drb.send_file source, file
          else
            LOG_ERROR 'send and receive must be file'

            false
          end
        when File.directory?(source)
          if not drb.function File, :file?, file
            if drb.function File, :mkdir, file
              status = true

              Dir.chdir source do
                File.glob('**/*').each do |name|
                  if block_given?
                    name = yield name
                  end

                  if name.nil?
                    next
                  end

                  remote_file = File.join file, name

                  case
                  when File.file?(name)
                    if not drb.send_file name, remote_file
                      status = false
                    end
                  when File.directory?(name)
                    if not drb.function File, :mkdir, remote_file
                      status = false
                    end
                  else
                    LOG_ERROR 'no such file or directory: %s' % File.expand_path(name)

                    status = false
                  end
                end
              end

              status
            else
              false
            end
          else
            LOG_ERROR 'send and receive must be directory'

            false
          end
        else
          LOG_ERROR 'no such file or directory: %s' % File.expand_path(source)

          false
        end
      end
    end

    def self.receive ip, source, file
      drb_connect ip do |drb|
        list = drb.function File, :list, source

        if not info.nil?
          if list.is_a? Array
            status = true

            # directory
            list.each do |name|
              if not name.end_with? '/'
                next
              end

              if block_given?
                name = yield name
              end

              if name.nil?
                next
              end

              if not File.mkdir File.join(file, name)
                status = false
              end
            end

            # file
            list.each do |name|
              if name.end_with? '/'
                next
              end

              if block_given?
                name = yield name
              end

              if name.nil?
                next
              end

              if not drb.receive_file File.join(file, name), File.join(source, name)
                status = false
              end
            end

            status
          else
            drb.receive_file file, source
          end
        else
          LOG_ERROR 'no such file or directory: %s' % [ip, source].utf8.join(':')

          false
        end
      end
    end
  end
end