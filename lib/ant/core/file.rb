require 'fileutils'
require 'pathname'

class File
  class << self
    alias __file__? file?
    alias __directory__? directory?
    alias __exist__? exist?

    alias __join__ join
    alias __expand_path__ expand_path
  end

  def self.file? file
    __file__? file.to_s.locale
  end

  def self.directory? file
    __directory__? file.to_s.locale
  end

  def self.exist? file
    __exist__? file.to_s.locale
  end

  def self.join *args
    __join__ args.locale
  end

  def self.expand_path filename, dir = nil
    __expand_path__ filename.locale, dir.locale
  end
end

class File
  def self.normalize filename
    File.join filename.split(/[\/\\]/)
  end

  def self.relative_path filename, dir = nil
    if dir.nil?
      dir = Dir.pwd
    end

    dir = File.expand_path dir

    if not dir.end_with? '/'
      dir += '/'
    end

    filename = File.expand_path filename

    begin
      Pathname.new(filename.locale).relative_path_from(Pathname.new(dir.locale)).to_s.locale
    rescue
      filename
    end
  end
end

class File
  def self.cmdline filename
    found = false

    filename.each_byte do |byte|
      if byte < 127
        if '-./:@[\]_{}~'.bytes.include? byte
          next
        end

        if OS::name == 'windows'
          if byte == 58
            next
          end
        end

        if byte >= 48 and byte <= 57
          next
        end

        if byte >= 65 and byte <= 90
          next
        end

        if byte >= 97 and byte <= 122
          next
        end

        found = true

        break
      end
    end

    if found
      "%s" % filename.gsub('"', '\"')
    else
      filename
    end
  end

  def self.glob xpath
    list = []

    if File.exist? xpath
      list << xpath
    else
      if File::FNM_SYSCASE.nonzero?
        Dir.glob(xpath.locale, File::FNM_CASEFOLD).each do |name|
          list << name
        end
      else
        Dir.glob(xpath.locale).each do |name|
          list << name
        end
      end
    end

    list.sort.locale
  end

  def self.list file
    case
    when File.file?(file)
      file
    when File.directory?(file)
      Dir.chdir file do
        list = []

        File.glob('**/*').each do |name|
          case
          when File.file?(name)
            list << name
          when File.directory?(name)
            list << name + '/'
          else
          end
        end

        list
      end
    else
      nil
    end
  end

  def self.lock filename, mode = 'r+:utf-8'
    filename = File.expand_path filename

    if not File.file? filename
      File.open filename, 'w:utf-8' do |file|
      end
    end

    File.open filename, mode do |file|
      file.flock File::LOCK_EX

      yield file
    end
  end

  def self.paths filename
    filename.locale.split /[\/\\]/
  end

  def self.root filename
    filename = File.expand_path filename

    if filename =~ /^(\w+:\/\/+[^\/\\]+)[\/\\]/
      if File::FNM_SYSCASE.nonzero?
        $1.downcase
      else
        $1
      end
    else
      loop do
        dir, name = File.split filename

        if dir == '.'
          if not filename.start_with? './'
            if File::FNM_SYSCASE.nonzero?
              return name.to_s.downcase
            else
              return name.to_s
            end
          end
        end

        if dir == filename
          if File::FNM_SYSCASE.nonzero?
            return dir.downcase
          else
            return dir
          end
        end

        filename = dir
      end
    end
  end

  def self.include? dirname, file
    if File::FNM_SYSCASE.nonzero?
      dirname = File.expand_path(dirname).downcase
      file = File.expand_path(file).downcase
    else
      dirname = File.expand_path dirname
      file = File.expand_path file
    end

    dirname == file or file.start_with? dirname + File::SEPARATOR
  end

  def self.same_path? filename, other_filename
    if File::FNM_SYSCASE.nonzero?
      filename = File.expand_path(filename).downcase
      other_filename = File.expand_path(other_filename).downcase
    else
      filename = File.expand_path filename
      other_filename = File.expand_path other_filename
    end

    filename == other_filename
  end
end

class File
  def self.tmpname
    '%s%04d' % [Time.now.timestamp, rand(1000)]
  end

  def self.tmpdir dir = nil, prefix = nil
    if dir.nil?
      dir = Dir.tmpdir
    end

    if prefix.nil?
      tmpdir = File.join dir, File.tmpname
    else
      tmpdir = File.join dir, '%s_%s' % [prefix, File.tmpname]
    end

    if block_given?
      begin
        FileUtils.mkdir_p tmpdir

        yield tmpdir
      ensure
        FileUtils.rm_rf tmpdir
      end
    else
      tmpdir
    end
  end
end

class File
  def self.mkdir dirname
    if not directory? dirname
      begin
        FileUtils.mkdir_p dirname.locale

        true
      rescue
        LOG_EXCEPTION $!

        false
      end
    else
      true
    end
  end

  def self.copy_file source, dest, preserve = true
    source = source.locale
    dest = dest.locale

    if not File.mkdir dirname(dest)
      return false
    end

    begin
      FileUtils.copy_file source, dest, preserve

      true
    rescue
      begin
        FileUtils.copy_file source, dest, false

        if preserve
          File.utime File.atime(source), File.mtime(source), dest
        end
      rescue
        LOG_EXCEPTION $!

        false
      end
    end
  end

  def self.delete_file file
    FileUtils.rm_rf file.locale

    if File.exist? file
      LOG_ERROR 'no delete file: %s' % file

      false
    else
      true
    end
  end

  def self.copy source, dest, preserve = true
    case
    when File.file?(source)
      if not File.directory? dest
        File.copy_file source, dest, preserve
      else
        LOG_ERROR 'source and destination must be file'

        false
      end
    when File.directory?(source)
      if not File.file? source
        status = true

        dest = File.expand_path dest

        Dir.chdir source do
          File.glob('**/*').each do |name|
            if block_given?
              name = yield name
            end

            if name.nil?
              next
            end

            dest_file = File.join dest, name

            case
            when File.file?(name)
              if not File.copy_file name, dest_file, preserve
                status = false
              end
            when File.directory?(name)
              if File.mkdir dest_file
                if preserve
                  File.utime File.atime(name), File.mtime(name), dest_file
                end
              else
                status = false
              end
            else
            end
          end
        end

        status
      else
        LOG_ERROR 'source and destination must be directory'

        false
      end
    else
      LOG_ERROR 'no such file or directory: %s' % source

      false
    end
  end

  def self.delete file
    case
    when File.file?(file)
      File.delete_file file
    when File.directory?(file)
      status = true

      ignore = []

      Dir.chdir file do
        File.glob('**/*').each do |name|
          delete_file = name

          if block_given?
            delete_file = yield name
          end

          if delete_file.nil?
            ignore << name

            next
          end

          if File.file? delete_file
            if not File.delete_file delete_file
              status = false
            end
          end
        end

        File.glob('**/*').each do |name|
          if File.directory? name
            found = false

            ignore.each do |ignore_file|
              if File.include? name, ignore_file
                found = true

                break
              end
            end

            if not found
              if not File.delete_file name
                status = false
              end
            end
          end
        end
      end

      if ignore.empty?
        if File.delete_file file
          status = true
        else
          status = false
        end
      end

      status
    else
      true
    end
  end
end