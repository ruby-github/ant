# ----------------------------------------------------------
#
# $console = true
# $backtrace = false
# $logging = false
#
# $log_level = LOG_PUTS
#
# $loggers = nil
# $errors = nil
#
# ----------------------------------------------------------

module COLOR
  module_function

  COLOR_TYPE = [
    COLOR_BLACK   = 30,
    COLOR_RED     = 31,
    COLOR_GREEN   = 32,
    COLOR_YELLOW  = 33,
    COLOR_BLUE    = 34,
    COLOR_MAGENTA = 35,
    COLOR_CYAN    = 36,
    COLOR_WHITE   = 37
  ]

  FONT_STYLE_TYPE = [
    FONT_CLEAR    = 0,
    FONT_HIGHLIGHT= 1,
    FONT_UNDERLINE= 4,
    FONT_SHINE    = 5,
    FONT_REVERSED = 7,
    FONT_INVISIBLE= 8
  ]

  HTML_COLOR = {
    COLOR_BLACK   => :black,
    COLOR_RED     => :red,
    COLOR_GREEN   => :green,
    COLOR_YELLOW  => :yellow,
    COLOR_BLUE    => :blue,
    COLOR_MAGENTA => :magenta,
    COLOR_CYAN    => :cyan,
    COLOR_WHITE   => :white
  }

  def COLOR string, fore_color = nil, back_color = nil, font_style = nil, html = false
    if not string.to_s.empty?
      if html
        style = []

        if not fore_color.nil?
          if COLOR_TYPE.include? fore_color
            style << 'color:%s' % HTML_COLOR[fore_color]
          end
        end

        if not back_color.nil?
          if COLOR_TYPE.include? back_color
            style << 'background:%s' % HTML_COLOR[back_color]
          end
        end

        if not font_style.nil?
          styles = []

          font_style.to_array.uniq.each do |style|
            if FONT_STYLE_TYPE.include? style
              styles << style
            end
          end

          if styles.include? FONT_UNDERLINE
            string = '<u>%s</u>' % string
          end

          if styles.include? FONT_HIGHLIGHT
            string = '<strong>%s</strong>' % string
          end
        end

        if not style.empty?
          "<font style='%s'>%s</font>" % [style.join(';'), string]
        else
          string
        end
      else
        if $console
          colorize = []

          if not fore_color.nil?
            if COLOR_TYPE.include? fore_color
              colorize << fore_color
            end
          end

          if not back_color.nil?
            if COLOR_TYPE.include? back_color
              colorize << back_color + 10
            end
          end

          if not font_style.nil?
            styles = []

            font_style.to_array.uniq.each do |style|
              if FONT_STYLE_TYPE.include? style
                styles << style
              end
            end

            if styles.size > 1
              styles.delete FONT_CLEAR
            end

            colorize += styles
          end

          if not colorize.empty?
            "\e[%sm%s\e[0m" % [colorize.join(';'), string]
          else
            string
          end
        else
          string
        end
      end
    else
      string
    end
  end
end

module LOG
  module_function

  LOG_TYPE = [
    LOG_DEBUG           = 1,
    LOG_PUTS            = 2,
    LOG_INFO            = 3,
    LOG_CMDLINE         = 4,
    LOG_WARN            = 5,
    LOG_ERROR           = 6,
    LOG_EXCEPTION       = 7,
    LOG_FATAL           = 8,
    LOG_CONSOLE         = 9
  ]

  LOG_LOCK = Monitor.new

  def LOG log_type, string, prefix = nil, io = $stdout
    if not LOG_TYPE.include? log_type
      log_type = LOG_PUTS
    end

    LOG_LOCK.synchronize do
      $log_level ||= LOG_PUTS

      if log_type >= $log_level
        line = string.to_s.utf8

        if not prefix.nil?
          line = [prefix, line].utf8.join ' '
        end

        if [LOG_CMDLINE, LOG_EXCEPTION].include? log_type
          lines = [line]

          case log_type
          when LOG_CMDLINE
            lines << '  (in %s)' % Dir.pwd.utf8
          when LOG_EXCEPTION
            if string.is_a? Exception
              if $backtrace
                string.backtrace.each do |line|
                  lines << line.to_s.utf8
                end
              end
            end
          else
          end

          line = lines.join "\n"
        end

        if not io.nil?
          if $logging
            $loggers ||= []
            $loggers << line
          end

          if [LOG_ERROR, LOG_EXCEPTION, LOG_FATAL].include? log_type
            $errors ||= []
            $errors << line
          end

          if $console
            io.puts line
            io.flush
          end
        else
          line
        end
      else
        nil
      end
    end
  end

  def get_loggers
    LOG_LOCK.synchronize do
      loggers = $loggers
      $loggers = nil

      loggers
    end
  end

  def get_errors
    LOG_LOCK.synchronize do
      errors = $errors
      $errors = nil

      errors
    end
  end
end

module LOG
  module_function

  def LOG_DEBUG string, io = $stdout
    LOG LOG_DEBUG, string, '[DEBUG]', io
  end

  def LOG_PUTS string, io = $stdout
    LOG LOG_PUTS, string, nil, io
  end

  def LOG_INFO string, io = $stdout
    LOG LOG_INFO, string, '[INFO]', io
  end

  def LOG_CMDLINE string, io = $stdout
    LOG LOG_CMDLINE, COLOR(string, COLOR_BLUE, nil, FONT_HIGHLIGHT), COLOR('$', COLOR_BLUE, nil, FONT_HIGHLIGHT), io
  end

  def LOG_WARN string, io = $stdout
    LOG LOG_WARN, string, COLOR('[WARN]', COLOR_YELLOW, nil, FONT_HIGHLIGHT), io
  end

  def LOG_ERROR string, io = $stdout
    LOG LOG_ERROR, string, COLOR('[ERROR]', COLOR_RED, nil, FONT_HIGHLIGHT), io
  end

  def LOG_EXCEPTION string, io = $stdout
    LOG LOG_EXCEPTION, string, COLOR('[EXCEPTION]', COLOR_RED, nil, FONT_HIGHLIGHT), io
  end

  def LOG_FATAL string, io = $stdout
    LOG LOG_FATAL, string, COLOR('[FATAL]', COLOR_RED, nil, FONT_HIGHLIGHT), io
  end

  def LOG_CONSOLE string, io = $stdout
    LOG LOG_CONSOLE, string, nil, io
  end

  def LOG_HEADLINE prefix = nil, io = $stdout
    prefix ||= '[INFO] '

    LOG_CONSOLE '%s%s' % [prefix, '-' * (80 - prefix.to_s.size)], io
  end

  def LOG_HEAD string, prefix = nil, io = $stdout
    string = string.utf8
    prefix = prefix.utf8

    if prefix.to_s.size >= 79
      prefix = prefix.to_s[0..10]
    end

    if not prefix.nil?
      prefix += ' '
    end

    lines = []

    lines << LOG_HEADLINE(prefix, nil)

    string.to_array.each_with_index do |line, index|
      if index > 0
        lines << line
      else
        lines << '%s%s' % [prefix, line]
      end
    end

    lines << LOG_HEADLINE(prefix, nil)

    LOG_CONSOLE lines.join("\n"), io
  end

  def LOG_SUMMARY title, command_list, total_time, io = $stdout
    lines = []

    lines << ''
    lines << LOG_HEADLINE(nil, nil)
    lines << '[INFO] %s:' % (title || 'Command Summary')
    lines << '[INFO]'

    size = 48

    command_list.each do |name, status, time|
      if [STDOUT, STDERR].include? io
        if name.to_s.locale.bytesize > size
          size = name.to_s.locale.bytesize
        end
      else
        if name.to_s.utf8.bytesize > size
          size = name.to_s.utf8.bytesize
        end
      end
    end

    if size > 78
      width = 78
    else
      width = size
    end

    success = 'SUCCESS'

    command_list.each do |name, status, time|
      if [STDOUT, STDERR].include? io
        name = name.to_s.locale
      else
        name = name.to_s.utf8
      end

      if name.bytesize > width
        wrap_lines = name.wrap(width).utf8

        lines << '[INFO] ' + wrap_lines.shift
        name = wrap_lines.pop

        wrap_lines.each do |x|
          lines << '       ' + x
        end

        if width > name.bytesize
          line = '       ' + name.utf8 + ' ' + '.' * (width - name.bytesize + 2)
        else
          line = '       ' + name.utf8
        end
      else
        line = '[INFO] ' + name.utf8 + ' ' + '.' * (width - name.bytesize + 2)
      end

      case status
      when false
        if time.nil?
          lines << '%s FAILURE' % line
        else
          lines << '%s FAILURE [ %10s]' % [line, Time.description(time)]
        end
      when nil
        lines << '%s SKIPPED' % line
      else
        if time.nil?
          lines << '%s SUCCESS' % line
        else
          lines << '%s SUCCESS [ %10s]' % [line, Time.description(time)]
        end
      end

      if status == false
        success = 'FAILURE'
      end
    end

    lines << LOG_HEADLINE(nil, nil)
    lines << '[INFO] EXECUTE %s' % success
    lines << LOG_HEADLINE(nil, nil)
    lines << '[INFO] Total time: %s' % Time.description(total_time)
    lines << '[INFO] Finished at: ' + Time.now.to_s
    lines << LOG_HEADLINE(nil, nil)
    lines << ''

    LOG_CONSOLE lines.join("\n"), io
  end
end

include COLOR
include LOG

if ENV['CONSOLE'] == '0'
  $console = false
else
  $console = true
end

$backtrace = false
$logging = false
$log_level = LOG_PUTS