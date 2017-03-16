module Package
  class FilePkg < Package
    Mixin::package self, 'file'

    def initialize name
      super name

      @file = File.expand_path @name
      @ignore = nil
    end

    def file file
      @file = File.expand_path file
    end

    def ignore ignore
      @ignore = ignore
    end

    def mkdir args = nil
      exec :mkdir, @file, args do
        Provide::File.mkdir @file
      end
    end

    def copy file, args = nil
      args ||= {}

      file = File.expand_path file
      preserve = args[:preserve] || true

      exec :copy, [@file, file].utf8.join(' -> '), args do
        Provide::File.copy @file, file, preserve do |name|
          if ignore? name
            nil
          else
            if block_given?
              yield name
            end

            name
          end
        end
      end
    end

    def delete args = nil
      exec :delete, @file, args do
        Provide::File.delete @file do |name|
          if ignore? name
            nil
          else
            if block_given?
              yield name
            end

            name
          end
        end
      end
    end

    def send ip, file, args = nil
      file = file.utf8
      args ||= {}

      exec :send, [@file, [ip, file].utf8.join(':')].utf8.join(' -> '), args do
        Provide::File.send @file, file do |name|
          if ignore? name
            nil
          else
            if block_given?
              yield name
            end

            name
          end
        end
      end
    end

    def receive ip, file, args = nil
      file = file.utf8

      exec :receive, [@file, [ip, file].utf8.join(':')].utf8.join(' <- '), args do
        Provide::File.receive @file, file do |name|
          if ignore? name
            nil
          else
            if block_given?
              yield name
            end

            name
          end
        end
      end
    end

    private

    def ignore? file
      case
      when @ignore.is_a?(String)
        @ignore.utf8 == file.utf8
      when @ignore.is_a?(Array)
        @ignore.utf8.include? file.utf8
      when @ignore.is_a?(Regexp)
        file.utf8 =~ @ignore
      when @ignore.is_a?(Proc)
        @ignore.call file.utf8
      else
        false
      end
    end
  end
end