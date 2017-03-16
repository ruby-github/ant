module Provide
  class Zip
    def initialize file
      @file = File.expand_path file
      @zip = nil
    end

    def open create = false
      begin
        if File.file? @file and not create
          @zip = ::Zip::File.new @file
        else
          @zip = ::Zip::File.new @file, ::Zip::File::CREATE
        end

        true
      rescue
        LOG_EXCEPTION $!

        @zip = nil

        false
      end
    end

    def mkdir path
      path = File.normalize path

      begin
        dup = path.locale.force_encoding 'ASCII-8BIT'

        if not @zip.find_entry dup
          mkdir_p dup
        end

        true
      rescue
        LOG_EXCEPTION $!

        false
      end
    end

    def add source, path = nil
      status = true

      source = File.expand_path source

      if not path.nil?
        path = File.normalize path
      end

      case
      when File.file?(source)
        if path.nil?
          dup = File.basename(source).locale.force_encoding 'ASCII-8BIT'
        else
          dup = path.locale.force_encoding 'ASCII-8BIT'
        end

        begin
          entry = @zip.find_entry dup

          if entry.nil?
            if File.dirname(dup) != '.'
              if not @zip.find_entry File.dirname(dup)
                mkdir_p File.dirname(dup)
              end
            end

            @zip.add dup, source
          else
            @zip.replace entry, source
          end
        rescue
          LOG_EXCEPTION $!

          status = false
        end
      when File.directory?(source)
        Dir.chdir source do
          File.glob('**/*').each do |name|
            if block_given?
              name = yield name
            end

            if name.nil?
              next
            end

            if path.nil?
              dup = name.locale.force_encoding 'ASCII-8BIT'
            else
              dup = File.join(path, name).locale.force_encoding 'ASCII-8BIT'
            end

            case
            when File.file?(name)
              begin
                entry = @zip.find_entry dup

                if entry.nil?
                  if File.dirname(dup) != '.'
                    if not @zip.find_entry File.dirname(dup)
                      mkdir_p File.dirname(dup)
                    end
                  end

                  @zip.add dup, name
                else
                  @zip.replace entry, name
                end
              rescue
                LOG_EXCEPTION $!

                status = false
              end
            when File.directory?(name)
              begin
                if not @zip.find_entry dup
                  mkdir_p dup
                end
              rescue
                LOG_EXCEPTION $!

                status = false
              end
            else
            end
          end
        end
      else
        LOG_ERROR 'no such file or directory: %s' % source

        status = false
      end

      status
    end

    def delete path
      path = File.normalize path

      begin
        dup = path.locale.force_encoding 'ASCII-8BIT'

        @zip.glob('**/*').each do |entry|
          if entry.to_s == dup
            @zip.remove entry

            next
          end

          if entry.to_s =~ /^#{dup}\//
            @zip.remove entry

            next
          end
        end

        true
      rescue
        LOG_EXCEPTION $!

        false
      end
    end

    def rename name, new_name
      name = File.normalize name
      new_name = File.normalize new_name

      begin
        dup = name.locale.force_encoding 'ASCII-8BIT'

        @zip.glob('**/*').each do |entry|
          if entry.to_s == dup
            @zip.rename entry, new_name.force_encoding('ASCII-8BIT')

            next
          end

          if entry.to_s =~ /^#{dup}\//
            @zip.rename entry, File.join(new_name, $').force_encoding('ASCII-8BIT')

            next
          end
        end

        true
      rescue
        LOG_EXCEPTION $!

        false
      end
    end

    def save
      begin
        @zip.commit

        true
      rescue
        LOG_EXCEPTION $!

        @zip.initialize @file

        false
      end
    end

    def close
      @zip = nil

      true
    end

    def unzip dest, paths = nil
      dest = File.normalize dest

      if not paths.nil?
        paths = paths.to_array.map {|name| File.normalize(name).force_encoding('ASCII-8BIT')}
      end

      status = true

      @zip.glob('**/*').each do |entry|
        if not paths.nil?
          found = false

          paths.each do |path|
            if entry.to_s == path
              found = true

              break
            end

            if entry.to_s =~ /^#{path}\//
              found = true

              break
            end
          end

          if not found
            next
          end
        end

        if block_given?
          name = yield entry.to_s.utf8

          if name.nil?
            next
          end
        end

        file = File.join dest.locale, entry.to_s.locale

        if not File.mkdir File.dirname(file)
          status = false

          next
        end

        begin
          @zip.extract entry, file do
            true
          end
        rescue
          LOG_EXCEPTION $!

          status = false
        end
      end

      status
    end

    private

    def mkdir_p path
      dup = []

      path.split('/').each do |name|
        dup << name

        if not @zip.find_entry File.join(dup)
          @zip.mkdir File.join(dup).force_encoding('ASCII-8BIT')
        end
      end
    end
  end
end