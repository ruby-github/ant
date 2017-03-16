module Package
  class Zip < Package
    Mixin::package self

    def initialize name
      super name

      @file = File.expand_path name
      @provide = nil
    end

    def file file
      @file = File.expand_path file
    end

    def open create = false, args = nil
      exec :open, nil, args do
        @provide = Provide::Zip.new @file
        @provide.open create
      end
    end

    def mkdir path, args = nil
      exec :mkdir, path, args do
        @provide.mkdir path
      end
    end

    def add source, path = nil, args = nil
      exec :add, source, args do
        @provide.add source, path do |name|
          if block_given?
            name = yield name
          end

          name
        end
      end
    end

    def delete path, args = nil
      exec :delete, path, args do
        @provide.delete path
      end
    end

    def rename name, new_name, args = nil
      exec :rename, [name, new_name].utf8.join(' -> '), args do
        @provide.rename name, new_name
      end
    end

    def save args = nil
      exec :save, nil, args do
        @provide.save
      end
    end

    def close args = nil
      exec :close, nil, args do
        @provide.close
      end
    end

    def unzip dest, paths = nil, args = nil
      exec :unzip, dest, args do
        @provide.unzip dest, paths do |name|
          if block_given?
            name = yield name
          end

          name
        end
      end
    end
  end
end