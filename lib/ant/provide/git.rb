module Provide
  module Git
    module_function

    def clone repository, path = nil, args = nil
      args ||= {}
      args[:submodule_init] = true

      cmdline = 'git clone'
      cmdline += ' -b %s' % (args[:branch] || 'master')

      if not args[:username].nil?
        if repository =~ /^(http|https|ssh):\/\//
          repository = '%s%s@%s' % [$&, args[:username], $']
        end
      end

      if not args[:arg].nil?
        cmdline += ' %s -- %s' % [args[:arg], repository]
      else
        cmdline += ' %s' % repository
      end

      if not path.nil?
        cmdline += ' %s' % File.cmdline(path)
      end

      authorization_init

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

        if path.nil?
          path = File.basename repository
        end

        submodule path, args do |line|
          if block_given?
            yield line
          end
        end
      else
        false
      end
    end

    def pull path = nil, args = nil
      args ||= {}
      path ||= '.'

      if File.directory? path
        Dir.chdir path do
          if args[:revert]
            revert do |line|
              if block_given?
                yield line
              end
            end
          end

          cmdline = 'git pull'

          if not args[:arg].nil?
            cmdline += ' %s' % args[:arg]
          end

          authorization_init

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

            submodule nil, args do |line|
              if block_given?
                yield line
              end
            end
          else
            false
          end
        end
      else
        LOG_ERROR 'no such directory: %s' % File.expand_path(path)

        false
      end
    end

    def push path = nil, args = nil
      args ||= {}
      path ||= '.'

      if File.directory? path
        Dir.chdir path do
          cmdline = 'git push'

          if not args[:arg].nil?
            cmdline += ' %s' % args[:arg]
          end

          authorization_init

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

        false
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
          cmdline = 'git commit'

          if not args[:arg].nil?
            cmdline += ' %s' % args[:arg]
          else
            cmdline += ' -a -m %s' % (args[:message] || 'commit')
          end

          if path == file
            cmdline += ' -- .'
          else
            cmdline += ' -- %s' % File.cmdline(File.basename(file))
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
        cmdline = 'git checkout'
        cmdline += ' -- %s' % File.cmdline(file)

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
          cmdline = 'git log'

          if not args[:arg].nil?
            cmdline += ' %s' % args[:arg]
          else
            cmdline += ' -1 --stat=256'
          end

          if path == file
            cmdline += ' -- .'
          else
            cmdline += ' -- %s' % File.cmdline(File.basename(file))
          end

          lines = []

          if CommandLine::cmdline cmdline do |line, stdin, wait_thr|
              lines << line

              if block_given?
                yield line
              end
            end

            logs = []
            info = nil
            comment = false

            git_home = home('.') || Dir.pwd

            lines.each do |line|
              line.rstrip!

              if line.strip =~ /^commit\s+([0-9a-fA-F]+)$/
                if not info.nil?
                  logs << info
                end

                info = {
                  revision: $1,
                  author:   nil,
                  email:    nil,
                  date:     nil,
                  comment:  nil,
                  changes:  nil
                }

                comment = false

                next
              end

              if line.strip =~ /^Author\s*:\s*(.*?)\s*<(.*?)>$/
                info[:author] = $1
                info[:email] = $2

                next
              end

              if line.strip =~ /^Date\s*:\s*/
                begin
                  info[:date] = Time.parse $'.strip
                rescue
                end

                comment = true

                next
              end

              if line.strip =~ /\|\s+(\d+\s+([+-]*)|Bin\s+(\d+)\s+->\s+(\d+)\s+bytes)$/
                name = $`.strip
                match_data = $~

                if name =~ /^\.{3}\//
                  Dir.chdir git_home do
                    name = File.glob(File.join('**', $')).first.to_s
                  end
                end

                if match_data[2].nil?
                  if match_data[3] == '0'
                    info[:changes] ||= {}
                    info[:changes][:add] ||= []
                    info[:changes][:add] << name
                  else
                    if match_data[4] == '0'
                      info[:changes] ||= {}
                      info[:changes][:delete] ||= []
                      info[:changes][:delete] << name
                    else
                      info[:changes] ||= {}
                      info[:changes][:update] ||= []
                      info[:changes][:update] << name
                    end
                  end
                else
                  if match_data[2].include? '+' and match_data[2].include? '-'
                    info[:changes] ||= {}
                    info[:changes][:update] ||= []
                    info[:changes][:update] << name
                  else
                    if match_data[2].include? '+'
                      info[:changes] ||= {}
                      info[:changes][:add] ||= []
                      info[:changes][:add] << name
                    else
                      info[:changes] ||= {}
                      info[:changes][:delete] ||= []
                      info[:changes][:delete] << name
                    end
                  end
                end

                comment = false

                next
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

    def config file = nil, args = nil
      args ||= {}
      file ||= '.'

      if File.directory? file
        path = file
      else
        path = File.dirname file
      end

      if File.directory? path
        Dir.chdir path do
          cmdline = 'git config'

          if not args[:arg].nil?
            cmdline += ' %s' % args[:arg]
          end

          cmdline += ' --list'

          lines = []

          if CommandLine::cmdline cmdline do |line, stdin, wait_thr|
              lines << line

              if block_given?
                yield line
              end
            end

            info = {}

            lines.each do |line|
              if line.strip =~ /=/
                info[$`] = $'
              end
            end

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

    def submodule path = nil, args = nil
      args ||= {}

      git_home = home path

      if not git_home.nil?
        if File.directory? git_home
          Dir.chdir git_home do
            if submodule?
              if args[:submodule_init]
                if not submodule_init nil, args do |line|
                    if block_given?
                      yield line
                    end
                  end

                  return false
                end

                if not submodule_update nil, args do |line|
                    if block_given?
                      yield line
                    end
                  end

                  return false
                end

                if not submodule_cmdline nil, 'git checkout %s' % (args[:branch] || 'master'), args do |line|
                    if block_given?
                      yield line
                    end
                  end

                  return false
                end
              end

              if not submodule_cmdline nil, 'git pull', args do |line|
                  if block_given?
                    yield line
                  end
                end

                return false
              end
            end
          end
        end
      end

      true
    end

    def submodule? path = nil
      path ||= '.'

      File.file? File.join(path, '.gitmodules')
    end

    def submodule_init path = nil, args = nil
      args ||= {}

      git_home = home path

      if not git_home.nil?
        if File.directory? git_home
          Dir.chdir git_home do
            if submodule?
              cmdline = 'git submodule init'

              if CommandLine::cmdline cmdline do |line, stdin, wait_thr|
                  if block_given?
                    yield line
                  end
                end

                true
              else
                false
              end
            else
              true
            end
          end
        else
          true
        end
      else
        true
      end
    end

    def submodule_update path = nil, args = nil
      args ||= {}

      git_home = home path

      if not git_home.nil?
        if File.directory? git_home
          Dir.chdir git_home do
            if submodule?
              cmdline = 'git submodule update'

              authorization_init

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
            else
              true
            end
          end
        else
          true
        end
      else
        true
      end
    end

    def submodule_cmdline path = nil, cmdline = nil, args = nil
      args ||= {}

      git_home = home path

      if not git_home.nil?
        if File.directory? git_home
          Dir.chdir git_home do
            if submodule?
              cmdline ||= 'git pull'
              cmdline = 'git submodule foreach %s' % cmdline

              authorization_init

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
            else
              true
            end
          end
        else
          true
        end
      else
        true
      end
    end

    def valid? path = nil
      if home(path).nil?
        false
      else
        true
      end
    end

    def authorization_init
      AskPass::set_askpass 'GIT_ASKPASS'
    end

    def authorization line, stdin, wait_thr, username, password
      if not stdin.nil? and not wait_thr.nil?
        case line.strip
        when /^Username\s+for\s+.*:$/
          AskPass::askpass username
        when /^Password\s+for\s+.*:$/
          AskPass::askpass password
        when /\(yes\/no\)\?/
          stdin.puts 'yes'
        else
          tmpline = wait_thr[:last].to_s
          wait_thr[:last] = ''

          if not tmpline.empty?
            case tmpline.strip
            when /^Username\s+for\s+.*:$/
              if block_given?
                yield tmpline
              end

              AskPass::askpass username
            when /^Password\s+for\s+.*:$/
              if block_given?
                yield tmpline
              end

              AskPass::askpass password
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
    end

    def home path = nil
      path ||= '.'
      path = File.expand_path path

      if File.file? path
        path = File.dirname path
      end

      if File.directory? path
        if File.exist? File.join(path, '.git')
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
      private :authorization_init, :authorization, :home
    end
  end

  module Git
    module_function

    def info file = nil
      logs = log file do |line|
        if block_given?
          yield line
        end
      end

      info = nil

      if not logs.nil?
        info = logs.last

        config = config file

        if not config.nil?
          url = config['remote.origin.url']

          if not url.nil?
            if url =~ /:\/\/(.*?)@/
              url = '%s://%s' % [$`, $']
            end

            if not file.nil?
              home = home file

              if not home.nil?
                info[:url] = File.join url, File.relative_path(file, home)
              end
            else
              info[:url] = url
            end
          end
        end
      end

      info
    end

    def update repository, path, args = nil
      if valid? path
        pull path, args do |line|
          if block_given?
            yield line
          end
        end
      else
        clone repository, path, args do |line|
          if block_given?
            yield line
          end
        end
      end
    end
  end
end