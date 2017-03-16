module Package
  class Git < Package
    Mixin::package self

    def initialize name
      super name

      @path = File.expand_path @name
    end

    def path path
      @path = File.expand_path path
    end

    def clone repository, args = nil
      exec :clone, repository, args do
        Provide::Git::clone repository, @path, args do |line|
          if block_given?
            yield line
          end
        end
      end
    end

    def pull args = nil
      exec :pull, nil, args do
        Provide::Git::pull @path, args do |line|
          if block_given?
            yield line
          end
        end
      end
    end

    def push args = nil
      exec :pull, nil, args do
        Provide::Git::push @path, args do |line|
          if block_given?
            yield line
          end
        end
      end
    end

    def commit file = nil, args = nil
      exec :commit, file, args do
        Provide::Git::commit file, args do |line|
          if block_given?
            yield line
          end
        end
      end
    end

    def revert file = nil, args = nil
      exec :revert, file, args do
        Provide::Git::revert file do |line|
          if block_given?
            yield line
          end
        end
      end
    end

    def log file = nil, args = nil
      exec :log, file, args do
        Provide::Git::log file, args do |line|
          if block_given?
            yield line
          end
        end
      end
    end

    def config file = nil, args = nil
      exec :config, file, args do
        Provide::Git::config file, args do |line|
          if block_given?
            yield line
          end
        end
      end
    end

    def info file = nil, args = nil
      exec :info, file, args do
        Provide::Git::info file do |line|
          if block_given?
            yield line
          end
        end
      end
    end

    def update repository, args = nil
      exec :update, repository, args do
        Provide::Git::update repository, @path, args do |line|
          if block_given?
            yield line
          end
        end
      end
    end
  end
end