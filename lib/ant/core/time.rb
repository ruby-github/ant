require 'time'

class Time
  def timestamp sep = ''
    strftime "%Y#{sep}%m#{sep}%d#{sep}%H#{sep}%M#{sep}%S"
  end

  def timestamp_day sep = ''
    strftime "%Y#{sep}%m#{sep}%d"
  end

  def to_s_with_usec
    '%s %s' % [strftime('%Y-%m-%d %H:%M:%S'), usec]
  end
end