module Package
  class Service < Package
    Mixin::package self

    def initialize name
      super name

      @file = nil
      @source = nil

      @expired = 300
    end

    def file file
      @file = File.expand_path file
    end

    def source file
      @source = File.expand_path file
    end

    def enable arg = nil, args = nil
      exec :enable, @file, args do
        Provide::Service::enable @name, @file, @source, arg do |line|
          if block_given?
            yield line
          end
        end
      end
    end

    def disable args = nil
      exec :disable, @file, args do
        Provide::Service::disable @name, @file do |line|
          if block_given?
            yield line
          end
        end
      end
    end

    def start args = nil
      exec :start, nil, args do
        Provide::Service::start @name, @expired do |line|
          if block_given?
            yield line
          end
        end
      end
    end

    def stop args = nil
      exec :stop, nil, args do
        Provide::Service::stop @name, @expired do |line|
          if block_given?
            yield line
          end
        end
      end
    end

    def restart args = nil
      exec :restart, nil, args do
        Provide::Service::restart @name, @expired do |line|
          if block_given?
            yield line
          end
        end
      end
    end
  end
end