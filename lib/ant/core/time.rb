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

class Time
  def self.description sec
    list = [nil, nil, nil]
    unit = 's'

    ['s', 'min', 'h'].each_with_index do |name, index|
      if index >= 2
        if sec > 0
          list[index] = sec
          unit = name
        end

        break
      end

      value = sec % 60

      if value > 0
        list[index] = value
        unit = name
      end

      sec = sec.to_i / 60
    end

    index = -1

    list.reverse.each do |x|
      if not x.nil?
        break
      end

      index -= 1
    end

    if list.size <= 1
      '%s s' % list.first.to_i
    else
      '%s %s' % [list[0..index].reverse.map {|x| '%02d' % x.to_i}.join(':'), unit]
    end
  end
end