module Package
  class Maven < Package
    Mixin::package self

    def initialize name
      super name

      @provide = Provide::Maven.new
      @provide.path @name
    end

    def path path
      @provide.path path
    end

    def clean args = nil
      args ||= {}

      skiperror = args[:skiperror].to_s.boolean true

      exec :clean, nil, args do
        @provide.clean args[:lang], skiperror do |line|
          if block_given?
            yield line
          end
        end
      end
    end

    def mvn cmdline = nil, args = nil
      args ||= {}

      clean = args[:clean].to_s.boolean false
      skiperror = args[:skiperror].to_s.boolean false

      exec :mvn, cmdline, args do
        @provide.mvn cmdline, clean, args[:lang], skiperror do |line|
          if block_given?
            yield line
          end
        end
      end
    end

    def mvn_retry cmdline = nil, args = nil
      args ||= {}

      exec :mvn_retry, cmdline, args do
        @provide.mvn_retry cmdline, args[:lang] do |line|
          if block_given?
            yield line
          end
        end
      end
    end

    def puts_errors
      @provide.puts_errors
    end

    def sendmail args = nil
      @provide.sendmail args
    end
  end
end