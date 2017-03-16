module Package
  class Gem < Package
    Mixin::package self

    def initialize name
      super name

      @file = nil
    end

    def file file
      @file = File.expand_path file
    end

    def install args = nil
      if @file.nil?
        name = @name
      else
        name = @file
      end

      exec :install, name, args do
        Provide::Gem::install name do |line|
          if block_given?
            yield line
          end
        end
      end
    end

    def uninstall args = nil
      if @file.nil?
        name = @name
      else
        name = @file
      end

      exec :uninstall, name, args do
        Provide::Gem::uninstall name do |line|
          if block_given?
            yield line
          end
        end
      end
    end
  end
end