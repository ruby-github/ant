module Package
  class Svn < Package
    Mixin::package self

    def initialize name
      super name

      @path = File.expand_path @name
    end

    def path path
      @path = File.expand_path path
    end

    def checkout repository, args = nil
      exec :checkout, repository, args do
        Provide::Svn::checkout repository, @path, args do |line|
          if block_given?
            yield line
          end
        end
      end
    end

    def commit file = nil, args = nil
      exec :commit, file, args do
        Provide::Svn::commit file, args do |line|
          if block_given?
            yield line
          end
        end
      end
    end

    def revert file = nil, args = nil
      exec :revert, file, args do
        Provide::Svn::revert file do |line|
          if block_given?
            yield line
          end
        end
      end
    end

    def cleanup path = nil, args = nil
      exec :cleanup, path, args do
        Provide::Svn::cleanup path do |line|
          if block_given?
            yield line
          end
        end
      end
    end

    def log file = nil, args = nil
      exec :log, file, args do
        Provide::Svn::log file, args do |line|
          if block_given?
            yield line
          end
        end
      end
    end

    def info file = nil, args = nil
      exec :info, file, args do
        Provide::Svn::info file do |line|
          if block_given?
            yield line
          end
        end
      end
    end

    def update repository, args = nil
      exec :update, repository, args do
        Provide::Svn::update repository, @path, args do |line|
          if block_given?
            yield line
          end
        end
      end
    end
  end
end