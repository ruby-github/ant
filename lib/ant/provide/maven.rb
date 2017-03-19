module Provide
  class Maven
    def initialize
      @path = Dir.pwd

      @errors = nil
      @lines = []

      @module_name = nil
      @module_home = Dir.pwd
    end

    def path path
      @path = File.expand_path path
    end

    def clean lang = nil, skiperror = true
      @errors = nil
      @lines = []

      if not File.directory? @path
        LOG_ERROR 'no such directory: %s' % @path

        return false
      end

      Dir.chdir @path do
        status = nil

        CommandLine::cmdline 'mvn clean -fn' do |line, stdin, wait_thr|
          if block_given?
            yield line
          end

          @lines << line

          status = validate status, line
        end

        if status
          @lines = []
        end

        if not skiperror
          set_errors lang
        end

        status
      end
    end

    def mvn cmdline = nil, clean = false, lang = nil, skiperror = false
      cmdline ||= 'mvn install -fn'

      @errors = nil
      @lines = []

      if not File.directory? @path
        LOG_ERROR 'no such directory: %s' % @path

        return false
      end

      Dir.chdir @path do
        if clean
          CommandLine::cmdline 'mvn clean -fn' do |line, stdin, wait_thr|
            if block_given?
              yield line
            end
          end
        end

        status = nil

        CommandLine::cmdline cmdline do |line, stdin, wait_thr|
          if block_given?
            yield line
          end

          @lines << line

          status = validate status, line
        end

        if status
          @lines = []
        end

        if not skiperror
          set_errors lang
        end

        status
      end
    end

    def mvn_retry cmdline = nil, lang = nil
      cmdline ||= 'mvn install -fn'

      @errors = nil

      if not File.directory? @path
        LOG_ERROR 'no such directory: %s' % @path

        return false
      end

      Dir.chdir @path do
        modules = retry_module

        if modules.empty?
          return true
        end

        @lines = []

        begin
          doc = REXML::Document.file 'pom.xml'

          REXML::XPath.each doc, '/project/artifactId' do |e|
            e.text = '%s-tmp' % e.text.to_s.strip
          end

          REXML::XPath.each doc, '/project/modules' do |e|
            doc.root.delete e
          end

          REXML::XPath.each doc, '/project/build' do |e|
            doc.root.delete e
          end

          e = REXML::Element.new 'modules'

          modules.each do |module_name, module_path|
            element = REXML::Element.new 'module'
            element.text = File.join '..', module_path
            e << element
          end

          doc.root << e

          if File.mkdir 'tmp'
            doc.to_file 'tmp/pom.xml'
          end
        rescue
        end

        if not File.file? 'tmp/pom.xml'
          LOG_ERROR 'no such file: %s' % File.expand_path('tmp/pom.xml')

          return false
        end

        status = nil

        Dir.chdir 'tmp' do
          CommandLine::cmdline cmdline do |line, stdin, wait_thr|
            if block_given?
              yield line
            end

            @lines << line

            status = validate status, line
          end

          if status
            @lines = []
          end

          set_errors lang
        end

        File.delete 'tmp'

        status
      end
    end

    def errors
      @errors
    end

    def puts_errors errors_list = nil
      errors_list ||= @errors

      if not errors_list.nil?
        # file
        #   module
        #   author
        #   date
        #   email
        #   url
        #   logs
        #   message
        #     lineno: message

        LOG_CONSOLE nil
        LOG_HEAD COLOR('COMPILATION ERROR', COLOR_RED, nil, FONT_HIGHLIGHT), '[INFO]'

        errors_list.to_array.each do |errors|
          if errors.nil?
            next
          end

          errors.each do |file, info|
            lines = []

            lines << 'File  : %s' % file
            lines << 'URL   : %s' % info[:url]
            lines << 'Module: %s' % info[:module]
            lines << 'Author: %s' % info[:author]
            lines << 'Date  : %s' % info[:date]
            lines << 'Email : %s' % info[:email]

            LOG_CONSOLE nil
            LOG_HEAD lines

            info[:message].each do |lineno, message|
              LOG_CONSOLE nil
              LOG_CONSOLE '  Line: %s' % lineno

              message.each do |line|
                LOG_CONSOLE '  %s' % line
              end
            end
          end
        end

        LOG_CONSOLE nil
      end
    end

    def sendmail errors_list = nil, args = nil
      errors_list ||= @errors
      args ||= {}

      if errors_list.nil?
        return true
      end

      map = {}

      errors_list.to_array.each do |errors|
        if errors.nil?
          next
        end

        errors.each do |file, info|
          email = info[:email]

          map[email] ||= {}
          map[email][file] = info
        end
      end

      status = true

      map.each do |email, errors|
        subject = 'Subject: %s(%s)' % [args[:subject] || '<BUILD 通知>编译失败, 请尽快处理', OS::name]

        if block_given?
          subject = yield subject
        end

        lines = []

        errors.each do |file, info|
          lines << '<br>'
          lines << '-' * 80 + '<br>'
          lines << '<b>File  : <font color = "red">%s</font></b><br>' % file
          lines << '<b>URL   : </b><a href = "%s">%s</a><br>' % [info[:url], info[:url]]
          lines << '<b>Module: %s</b><br>' % info[:module]
          lines << '<b>Author: %s</b><br>' % info[:author]
          lines << '<b>Date  : %s</b><br>' % info[:date]
          lines << '<b>Email : %s</b><br>' % info[:email]
          lines << '-' * 80 + '<br>'

          info[:message].each do |lineno, message|
            lines << '<br>'
            lines << '  <b>Line: %s</b><br>' % lineno

            lines << '<pre>'

            message.each do |line|
              lines << '  %s' % line
            end

            lines << '</pre>'
          end

          lines << '<br>'
        end

        args[:html] = lines.join "\n"

        if args[:email]
          email = args[:email]
        end

        if not Net::send_smtp nil, nil, email, args do |mail|
            File.tmpdir do |dirname|
              errors.each do |file, info|
                if not info[:logs].nil?
                  filename = File.join dirname, 'logs(%s).log' % info[:module]

                  File.open filename, 'w:utf-8' do |file|
                    file.puts info[:logs]
                  end

                  mail.attach filename.locale
                end
              end
            end
          end

          status = false
        end
      end

      status
    end

    private

    def artifactid path
      case
      when File.file?(path)
        artifactid File.dirname(path)
      when File.directory?(path)
        if File.file? File.join(path, 'pom.xml')
          begin
            doc = REXML::Document.file File.join(path, 'pom.xml')

            artifactId = nil

            REXML::XPath.each doc, '/project/artifactId' do |e|
              artifactId = e.text.to_s.nil
            end

            artifactId
          rescue
            nil
          end
        else
          if File.dirname(path) == path
            nil
          else
            artifactid File.dirname(path)
          end
        end
      else
        nil
      end
    end

    def artifactid_paths dirname
      dirname ||= '.'

      map = {}

      if File.file? File.join(dirname, 'pom.xml')
        Dir.chdir dirname do
          begin
            doc = REXML::Document.file 'pom.xml'

            REXML::XPath.each doc, '/project/artifactId' do |e|
              artifactId = e.text.to_s.nil

              if not artifactId.nil?
                map[artifactId] = Dir.pwd
              end
            end

            REXML::XPath.each doc, '//modules/module' do |e|
              module_path = e.text.to_s.nil

              if not module_path.nil?
                map = map.deep_merge artifactid_paths(module_path)
              end
            end
          rescue
          end
        end
      end

      map
    end

    def retry_module
      modules = {}

      start = false

      @lines.each_with_index do |line, index|
        line.strip!

        if line =~ /^\[INFO\]\s+Reactor\s+Summary:$/
          start = true
        end

        if line =~ /^\[INFO\]\s+BUILD\s+(SUCCESS|FAILURE)$/
          start = false
        end

        if start
          if line =~ /^\[INFO\]\s+(.*?)\s+\.+\s*(FAILURE|SKIPPED)/
            modules[$1] = nil
          end
        end
      end

      if not modules.empty?
        paths = artifactid_paths @path

        modules.keys.each do |module_name|
          path = paths[module_name]

          if path.nil?
            modules.delete module_name

            LOG_ERROR 'no found pom module: %s' % module_name
          else
            modules[module_name] = File.relative_path path, Dir.pwd
          end
        end
      end

      modules
    end

    def set_errors lang = nil
      @errors = nil

      @module_name = nil
      @module_home = Dir.pwd

      start = nil
      logs = {}

      @lines.each_with_index do |line, index|
        line.strip!

        if line =~ /^\[INFO\]\s+Building\s+/
          start = true

          if not @module_name.nil?
            if index > 1
              logs[@module_name][-1] = index - 2
            else
              logs[@module_name][-1] = index
            end
          end

          @module_name = $'.split(/\s+/).first

          if index > 0
            logs[@module_name] = [index - 1, -1]
          else
            logs[@module_name] = [index, -1]
          end

          next
        end

        if line =~ /^\[INFO\]\s+BUILD\s+(SUCCESS|FAILURE)$/
          start = false

          if not @module_name.nil?
            if logs[@module_name].last == -1
              if index > 0
                logs[@module_name][-1] = index - 1
              else
                logs[@module_name][-1] = index
              end
            end

            @module_name = nil
          end

          next
        end

        if start
          case lang
          when :cpp
            set_errors_cpp line, index
          else
            set_errors_java line, index
          end
        else
          if not start.nil?
            if line =~ /^\[ERROR\]\s+.*\s+on\s+project\s+(.*?)\s*:/
              @module_name = $1

              found = false

              if not @errors.nil?
                @errors.each do |file, info|
                  if info[:module] == @module_name
                    found = true

                    break
                  end
                end
              end

              if not found
                file = nil
                lineno = nil
                message = [line]

                500.times do |i|
                  tmpindex = index + i + 1

                  if tmpindex >= @lines.size
                    break
                  end

                  tmpline = @lines[tmpindex]

                  if tmpline.nil?
                    next
                  end

                  tmpline.strip!

                  if tmpline =~ /^\[ERROR\]\s+->\s+\[Help\s+.*\]$/
                    break
                  end

                  if tmpline =~ /^\[ERROR\]\s+.*\s+in\s+(.*?)\/target\//
                    file = File.expand_path $1
                  end

                  if tmpline =~ /^\[INFO\]\s+Building\s+/
                    break
                  end

                  message << tmpline
                end

                @errors ||= {}
                @errors[file] ||= {
                  :module => @module_name,
                  :logs   => nil,
                  :message=> {}
                }

                @errors[file][:message][lineno] = message
              end

              @module_name = nil

              next
            end
          end
        end
      end

      if not @errors.nil?
        @errors.keys.each do |file|
          if not file.nil?
            artifactId = artifactid file

            if not artifactId.nil?
              logs_info = logs[artifactId]

              if not logs_info.nil?
                @errors[file][:logs] = @lines[logs_info.first..logs_info.last]
              end
            end

            author, email, date, url = scm_info file

            @errors[file][:author] = author
            @errors[file][:email] = email
            @errors[file][:date] = date
            @errors[file][:url] = url
          end
        end
      end

      @errors
    end

    def set_errors_java line, index
      if line =~ /\s+Compiling\s+\d+\s+source\s+(file|files)\s+to\s+(.*)\/target\//
        @module_home = $2

        return true
      end

      if line =~ /^\[ERROR\]\s+(.+):\[(\d+),\d+\]/
        if not @module_home.nil? and File.directory? @module_home
          Dir.chdir @module_home do
            file = File.expand_path $1
            lineno = $2.to_i
            message = [line]

            10.times do |i|
              tmpindex = index + i + 1

              if tmpindex >= @lines.size
                break
              end

              tmpline = @lines[tmpindex]

              if tmpline.nil?
                next
              end

              tmpline.strip!

              if tmpline =~ /^\[INFO\]\s+\d+(error|errors)$/
                break
              end

              if tmpline =~ /^\[INFO\]/
                next
              end

              message << tmpline
            end

            @errors ||= {}
            @errors[file] ||= {
              :module => @module_name,
              :logs   => nil,
              :message=> {}
            }

            @errors[file][:message][lineno] = message
          end

          return true
        else
          return false
        end
      end

      if line =~ /^Tests\s+run\s*:\s*(\d+)\s*,\s*Failures\s*:\s*(\d+)\s*,\s*Errors\s*:\s*(\d+)\s*,\s*Skipped\s*:\s*(\d+)\s*,\s*.*FAILURE.*\s*-\s*in\s+/
        if not @module_home.nil? and File.directory? @module_home
          Dir.chdir @module_home do
            if $2.to_i > 0 or $3.to_i > 0
              filename = '%s.java' % $'.gsub('.', '/')
              file = nil

              if File.file? File.join('src/test/java', filename)
                file = File.expand_path File.join('src/test/java', filename)
              else
                File.glob(File.join('**', filename)).each do |name|
                  file = File.expand_path name

                  if name.start_with? 'src/'
                    break
                  end
                end
              end

              if not file.nil?
                lineno = nil
                message = [line]

                10.times do |i|
                  tmpindex = index + i + 1

                  if tmpindex >= @lines.size
                    break
                  end

                  tmpline = @lines[tmpindex]

                  if tmpline.nil?
                    next
                  end

                  tmpline.strip!

                  if tmpline =~ /^at\s+.*\(#{File.basename(filename)}\s*:\s*(\d+)\)$/
                    lineno = $1.to_i
                    message << tmpline

                    break
                  end

                  message << tmpline
                end

                @errors ||= {}
                @errors[file] ||= {
                  :module => @module_name,
                  :logs   => nil,
                  :message=> {}
                }

                @errors[file][:message][lineno] = message
              end
            end
          end

          return true
        else
          return false
        end
      end

      nil
    end

    def set_errors_cpp line, index
      if line =~ /\s+\/bin\/sh\s+-c\s+cd\s+(.*?)\s+&&\s+/
        @module_home = $1

        return true
      end

      if line =~ /\s+\/Fo(.*?)\\target\\objs\\.*\.obj\s+-c\s+/
        @module_home = $1

        return true
      end

      # compile
      #   linux   : /:\s*(\d+)\s*:\s*(\d+)\s*:\s*\w*\s*(error|错误)\s*\w*\d*(:|：)/
      #   solaris : /,\s*第\s*(\d+)\s*行:\s*(error|错误)\s*,/
      #   windows : /\((\d+)\)\s*:\s*\w*\s*(error|错误)\s*\w*\d*(:|：)/, /:\s*(\d+)\s*:\s*\w*\s*(error|错误)\s*\w*\d*(:|：)/
      if line =~ /:\s*(\d+)\s*:\s*(\d+)\s*:\s*\w*\s*(error|错误)\s*\w*\d*(:|：)/ or
        line =~ /,\s*第\s*(\d+)\s*行:\s*(error|错误)\s*,/ or
        line =~ /\((\d+)\)\s*:\s*\w*\s*(error|错误)\s*\w*\d*(:|：)/ or
        line =~ /:\s*(\d+)\s*:\s*\w*\s*(error|错误)\s*\w*\d*(:|：)/

        if not @module_home.nil? and File.directory? @module_home
          Dir.chdir @module_home do
            file = $`.strip.nil
            lineno = $1.to_i
            message = [line]

            if file =~ /^"(.*)"$/
              file = $1.strip.nil
            end

            if not file.nil?
              file = File.expand_path file

              @errors ||= {}
              @errors[file] ||= {
                :module => @module_name,
                :logs   => nil,
                :message=> {}
              }

              @errors[file][:message][lineno] = message
            end
          end

          return true
        else
          return false
        end
      end

      # link
      #   linux   : /collect2\s*:\s*ld\s+/, /:\s*(\d+)\s*:\s*undefined\s+reference\s+to\s+/
      #   solaris : /ld\s*:\s*.*:\s*symbol\s+referencing\s+errors\./, /\s+target\/objs\/(.*?)\.o$/
      #   windows : /\s*:\s*fatal\s+error\s+LNK\d+\s*:/, /:\s*error\s+LNK\d+\s*:\s*unresolved\s+external\s+symbol\s+/
      if line =~ /collect2\s*:\s*ld\s+/ or
        line =~ /ld\s*:\s*.*:\s*symbol\s+referencing\s+errors\./ or
        line =~ /\s*:\s*fatal\s+error\s+LNK\d+\s*:/

        case line
        when /collect2\s*:\s*ld\s+/
          osname = :linux
        when /ld\s*:\s*.*:\s*symbol\s+referencing\s+errors\./
          osname = :solaris
        when /\s*:\s*fatal\s+error\s+LNK\d+\s*:/
          osname = :windows
        else
          osname = nil
        end

        if not @module_home.nil? and File.directory? @module_home
          Dir.chdir @module_home do
            file = Dir.pwd
            lineno = nil
            message = []

            500.times do |i|
              tmpindex = index - i - 1

              if tmpindex < 0
                break
              end

              tmpline = @lines[tmpindex]

              if tmpline.nil?
                next
              end

              tmpline.strip!

              if tmpline =~ /:\s*link\s+\(default-link\)\s+@/
                break
              end

              if (osname == :linux and tmpline =~ /:\s*(\d+)\s*:\s*undefined\s+reference\s+to\s+/) or
                (osname == :solaris and tmpline =~ /\s+target\/objs\/(.*?)\.o$/) or
                (osname == :windows and tmpline =~ /:\s*error\s+LNK\d+\s*:\s*unresolved\s+external\s+symbol\s+/)
                message << tmpline
              end
            end

            @errors ||= {}
            @errors[file] ||= {
              :module => @module_name,
              :logs   => nil,
              :message=> {}
            }

            @errors[file][:message][lineno] = message.reverse
          end

          return true
        else
          return false
        end
      end

      nil
    end

    def scm_info file
      author = nil
      email = nil
      date = nil
      url = nil

      if not file.nil?
        case
        when Git::valid?(file)
          info = Git::info file
        when Svn::valid?(file)
          info = Svn::info file
        else
          nil
        end

        if not info.nil?
          author = info[:author]
          email = info[:email]
          date = info[:date]
          url = info[:url]
        end
      end

      [author, email, date, url]
    end

    def validate status, line
      if line.strip =~ /^\[INFO\]\s+BUILD\s+(SUCCESS|FAILURE)$/
        if $1 == 'SUCCESS'
          if status.nil?
            true
          else
            status
          end
        else
          false
        end
      else
        status
      end
    end
  end
end