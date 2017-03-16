class Hash
  def dclone
    dup = super
    dup.clear

    each do |k, v|
      dup[k.dclone] = v.dclone
    end

    dup
  end
end

class Hash
  def locale
    dup = super
    dup.clear

    each do |k, v|
      dup[k.locale] = v.locale
    end

    dup
  end

  def utf8
    dup = super
    dup.clear

    each do |k, v|
      dup[k.utf8] = v.utf8
    end

    dup
  end

  def to_string
    lines = []

    if empty?
      lines << '{}'
    else
      lines << '{'

      tmp = []

      each do |k, v|
        tmp << INDENT + ("%s => %s" % [k.to_string, v.to_string]).lines.join(INDENT)
      end

      lines << tmp.join(",\n")

      lines << '}'
    end

    lines.join "\n"
  end

  def to_json_string
    lines = []

    if empty?
      lines << '{}'
    else
      lines << '{'

      tmp = []

      each do |k, v|
        tmp << INDENT + ('%s: %s' % [k.to_s.to_json_string, v.to_json_string]).lines.join(INDENT)
      end

      lines << tmp.join(",\n")

      lines << '}'
    end

    lines.join "\n"
  end
end

class Hash
  def deep_merge hash, &block
    dup = dclone

    hash.each do |k, v|
      if dup.has_key? k
        value = dup[k]

        if value.is_a? Hash and v.is_a? Hash
          dup[k] = value.deep_merge v, &block
        else
          if block
            dup[k] = block.call k, value, v
          else
            dup[k] = v
          end
        end
      else
        dup[k] = v
      end
    end

    dup
  end

  def expand args = nil
    args = args.dup || {}

    attributes = {}

    each do |name, value|
      if [String, Symbol].include? name.class
        if name =~ /\$(\(([\w.:-]+)\)|{([\w.:-]+)})/
          next
        end

        if [String, Symbol, Integer, Float, TrueClass, FalseClass, NilClass].include? value.class
          attributes[name] = value.to_s.expand args
          args[name] = attributes[name]
        end
      end
    end

    3.times do
      attributes.each do |name, value|
        attributes[name] = value.expand args
        args[name] = attributes[name]
      end
    end

    dup = {}

    each do |k, v|
      dup[k] = v.expand args
    end

    dup
  end
end