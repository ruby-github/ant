module Provide
  module Svn
    module_function

    def checkout repository, path = nil, args = nil
      args ||= {}

      cmdline = 'svn checkout'

      if not args[:username].nil?
        if repository =~ /^(http|https|ssh):\/\//
          repository = '%s%s@%s' % [$&, args[:username], $']
        end
      end

      if not args[:arg].nil?
        cmdline += ' %s' % args[:arg]
      end

      cmdline += ' %s' % repository

      if not path.nil?
        cmdline += ' %s' % File.cmdline(path)
      end

      if CommandLine::cmdline cmdline do |line, stdin, wait_thr|
          if block_given?
            yield line
          end

          authorization line, stdin, wait_thr, args[:username], args[:password] do |tmpline|
            if block_given?
              yield tmpline
            end
          end
        end

        true
      else
        false
      end
    end

    def __update__ file, args = nil
      args ||= {}
      file ||= '.'

      if File.directory? file
        path = file
      else
        path = File.dirname file
      end

      if File.directory? path
        Dir.chdir path do
          cmdline = 'svn update --force'

          if not args[:arg].nil?
            cmdline += ' %s' % args[:arg]
          end

          if path == file
            cmdline += ' .'
          else
            cmdline += ' %s' % File.cmdline(File.basename(file))
          end

          if CommandLine::cmdline cmdline do |line, stdin, wait_thr|
              if block_given?
                yield line
              end

              authorization line, stdin, wait_thr, args[:username], args[:password] do |tmpline|
                if block_given?
                  yield tmpline
                end
              end
            end

            true
          else
            false
          end
        end
      else
        LOG_ERROR 'no such directory: %s' % File.expand_path(path)

        nil
      end
    end

    def commit file = nil, args = nil
      args ||= {}
      file ||= '.'

      if File.directory? file
        path = file
      else
        path = File.dirname file
      end

      if File.directory? path
        Dir.chdir path do
          cmdline = 'svn commit'

          if not args[:arg].nil?
            cmdline += ' %s' % args[:arg]
          else
            cmdline += ' -m %s' % (args[:message] || 'commit')
          end

          if path == file
            cmdline += ' .'
          else
            cmdline += ' %s' % File.cmdline(File.basename(file))
          end

          if CommandLine::cmdline cmdline do |line, stdin, wait_thr|
              if block_given?
                yield line
              end
            end

            true
          else
            false
          end
        end
      else
        LOG_ERROR 'no such directory: %s' % File.expand_path(path)

        false
      end
    end

    def revert file = nil
      file ||= '.'

      file = File.expand_path file
      path = File.dirname file

      if not File.directory? path
        path = home('.') || Dir.pwd
      end

      Dir.chdir path do
        cmdline = 'svn revert -R'
        cmdline += ' %s' % File.cmdline(file)

        if CommandLine::cmdline cmdline do |line, stdin, wait_thr|
            if block_given?
              yield line
            end
          end

          true
        else
          false
        end
      end
    end

    def cleanup path = nil
      path ||= '.'

      if File.directory? path
        Dir.chdir path do
          cmdline = 'svn cleanup'

          if CommandLine::cmdline cmdline do |line, stdin, wait_thr|
              if block_given?
                yield line
              end
            end

            true
          else
            false
          end
        end
      else
        LOG_ERROR 'no such directory: %s' % File.expand_path(path)

        false
      end
    end

    def log file = nil, args = nil
      args ||= {}
      file ||= '.'

      if File.directory? file
        path = file
      else
        path = File.dirname file
      end

      if File.directory? path
        Dir.chdir path do
          cmdline = 'svn log'

          if not args[:arg].nil?
            cmdline += ' %s' % args[:arg]
          else
            cmdline += ' --verbose -l 1'
          end

          if path == file
            cmdline += ' .'
          else
            cmdline += ' %s' % File.cmdline(File.basename(file))
          end

          lines = []

          if CommandLine::cmdline cmdline do |line, stdin, wait_thr|
              lines << line

              if block_given?
                yield line
              end

              authorization line, stdin, wait_thr, args[:username], args[:password] do |tmpline|
                if block_given?
                  yield tmpline
                end
              end
            end

            logs = []
            info = nil
            change = false
            comment = false

            lines.each do |line|
              line.rstrip!

              if line.strip =~ /^-+$/
                if not info.nil?
                  logs << info

                  info = nil
                end

                change = false
                comment = false

                next
              end

              if line.strip =~ /^r(\d+)\s+\|\s+(.+)\s+\|\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\s+[+-]\d{4})\s+.*\|/
                info = {
                  revision: $1.to_i,
                  author:   $2,
                  email:    nil,
                  date:     nil,
                  comment:  nil,
                  changes:  nil
                }

                info[:email] = author2email info[:author]

                begin
                  info[:date] = Time.parse $3
                rescue
                end

                comment = true

                next
              end

              if line.strip =~ /^(Changed\s+paths|改变的路径):$/
                change = true
                comment = false

                next
              end

              if change
                if line.strip.empty?
                  change = false
                  comment = true

                  next
                end

                if line.strip =~ /^([A-Z])\s+(.*)$/
                  flag = $1
                  name = $2

                  if name.start_with? '/'
                    name = name[1..-1]
                  end

                  if name =~ /\(from\s+.*:\d+\)$/
                    name = $`.strip
                  end

                  case flag
                  when 'A'
                    info[:changes] ||= {}
                    info[:changes][:add] ||= []
                    info[:changes][:add] << name
                  when 'D'
                    info[:changes] ||= {}
                    info[:changes][:delete] ||= []
                    info[:changes][:delete] << name
                  else
                    info[:changes] ||= {}
                    info[:changes][:update] ||= []
                    info[:changes][:update] << name
                  end
                end
              end

              if comment
                if line.empty?
                  if not info[:comment].nil?
                    if not info[:comment].last.empty?
                      info[:comment] << line
                    end
                  end
                else
                  info[:comment] ||= []
                  info[:comment] << line
                end

                next
              end
            end

            if not info.nil?
              logs << info
            end

            logs.reverse
          else
            nil
          end
        end
      else
        LOG_ERROR 'no such directory: %s' % File.expand_path(path)

        nil
      end
    end

    def info file = nil
      file ||= '.'

      if File.directory? file
        path = file
      else
        path = File.dirname file
      end

      if File.directory? path
        Dir.chdir path do
          cmdline = 'svn info'

          if path == file
            cmdline += ' .'
          else
            cmdline += ' %s' % File.cmdline(File.basename(file))
          end

          lines = []

          if CommandLine::cmdline cmdline do |line, stdin, wait_thr|
              lines << line

              if block_given?
                yield line
              end

              authorization line, stdin, wait_thr, args[:username], args[:password] do |tmpline|
                if block_given?
                  yield tmpline
                end
              end
            end

            info = {}

            lines.each do |line|
              line.strip!

              case line
              when /^(URL)(:|：)\s*/
                info[:url] = $'.gsub '%20', ' '
              when /^(Last\s+Changed\s+Author|最后修改的作者)(:|：)\s*/
                info[:author] = $'
              when /^(Last\s+Changed\s+Date|最后修改的时间)(:|：)\s*/
                begin
                  info[:date] = Time.parse $'
                rescue
                end
              when /^(Last Changed Rev|最后修改的版本)(:|：)\s*/
                info[:revision] = $'.to_i
              else
              end
            end

            info[:email] = author2email info[:author]

            info
          else
            nil
          end
        end
      else
        LOG_ERROR 'no such directory: %s' % File.expand_path(path)

        nil
      end
    end

    def valid? path = nil
      if home(path).nil?
        false
      else
        true
      end
    end

    def authorization line, stdin, wait_thr, username, password
      case line.strip
      when /^(Username|用户名):$/
        stdin.puts username
      when /(Password\s+for\s+.*|的密码):$/
        stdin.puts password
      when /\(p\)(ermanently|永远接受)(\?|？)/
        stdin.puts 'p'
      when /\(yes\/no\)\?/
        stdin.puts 'yes'
      else
        tmpline = wait_thr[:last].to_s
        wait_thr[:last] = ''

        if not tmpline.empty?
          case tmpline.strip
          when /^(Username|用户名):$/
            if block_given?
              yield tmpline
            end

            stdin.puts username
          when /(Password\s+for\s+.*|的密码):$/
            if block_given?
              yield tmpline
            end

            stdin.puts password
          when /\(p\)(ermanently|永远接受)(\?|？)/
            if block_given?
              yield tmpline
            end

            stdin.puts 'p'
          when /\(yes\/no\)\?/
            if block_given?
              yield tmpline
            end

            stdin.puts 'yes'
          else
            wait_thr[:last] = tmpline
          end
        end
      end
    end

    def author2email author
      if not author.nil?
        if author =~ /\d+$/
          '%s@zte.com.cn' % $&
        else
          nil
        end
      else
        nil
      end
    end

    def home path = nil
      path ||= '.'
      path = File.expand_path path

      if File.file? path
        path = File.dirname path
      end

      if File.directory? path
        if File.exist? File.join(path, '.svn')
          path
        else
          if File.dirname(path) == path
            nil
          else
            home File.dirname(path)
          end
        end
      else
        nil
      end
    end

    class << self
      private :authorization, :author2email, :home
    end
  end

  module Svn
    module_function

    def update repository, path, args = nil
      if valid? path
        __update__ file, args do |line|
          if block_given?
            yield line
          end
        end
      else
        checkout repository, path, args do |line|
          if block_given?
            yield line
          end
        end
      end
    end
  end
end