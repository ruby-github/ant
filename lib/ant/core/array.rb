class Array
  def dclone
    dup = super
    dup.clear

    each do |x|
      dup << x.dclone
    end

    dup
  end
end

class Array
  def locale
    dup = super
    dup.clear

    each do |x|
      dup << x.locale
    end

    dup
  end

  def utf8
    dup = super
    dup.clear

    each do |x|
      dup << x.utf8
    end

    dup
  end

  def to_array
    self
  end

  def to_string
    lines = []

    if empty?
      lines << '[]'
    else
      lines << '['

      tmp = []

      each do |x|
        tmp << INDENT + x.to_string.lines.join(INDENT)
      end

      lines << tmp.join(",\n")

      lines << ']'
    end

    lines.join "\n"
  end

  def to_json_string
    lines = []

    if empty?
      lines << '[]'
    else
      lines << '['

      tmp = []

      each do |x|
        tmp << INDENT + x.to_json_string.lines.join(INDENT)
      end

      lines << tmp.join(",\n")

      lines << ']'
    end

    lines.join "\n"
  end
end

class Array
  def deep_merge array, &block
    dup = dclone

    array.each_with_index do |x, index|
      if index < dup.size
        value = dup[index]

        if value.is_a? Array and x.is_a? Array
          dup[index] = value.deep_merge x, &block
        else
          if block
            dup[index] = block.call value, x
          else
            if value.nil? || x.nil?
              dup[index] = value || x
            else
              begin
                dup[index] = value + x
              rescue
                dup[index] = value.to_i + x.to_i
              end
            end
          end
        end
      else
        dup[index] = x
      end
    end

    dup
  end

  def expand args = nil
    dup = []

    each do |x|
      dup << x.expand(args)
    end

    dup
  end

  def flat_expand
    dup = []

    each do |x|
      if x.is_a? Array
        dup += x.flat_expand
      else
        dup << x
      end
    end

    dup
  end
end