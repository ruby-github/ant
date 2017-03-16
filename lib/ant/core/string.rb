Encoding.default_internal ||= Encoding.default_external

class String
  def locale
    dup = self.dup

    begin
      encoding = dup.encoding?

      if encoding.nil?
        dup.force_encoding self.encoding
      else
        dup.force_encoding encoding
      end

      if self.encoding != Encoding.default_external
        dup = dup.encode 'locale', invalid: :replace, undef: :replace, replace: ''
      end

      dup
    rescue
      self.dup
    end
  end

  def utf8
    dup = self.dup

    begin
      encoding = dup.encoding?

      if encoding.nil?
        dup.force_encoding self.encoding
      else
        dup.force_encoding encoding
      end

      if self.encoding != Encoding::UTF_8
        dup = dup.encode 'utf-8', invalid: :replace, undef: :replace, replace: ''
      end

      dup
    rescue
      self.dup
    end
  end

  def encoding?
    if encoding != Encoding::ASCII_8BIT and valid_encoding?
      encoding.to_s
    else
      name_list = ['utf-8', 'locale', 'external', 'filesystem']
      name_list += Encoding.name_list

      name_list.uniq.each do |name|
        if name == 'ASCII-8BIT'
          next
        end

        if dup.force_encoding(name).valid_encoding?
          return name
        end
      end

      nil
    end
  end
end

class String
  def boolean default = nil
    case downcase.strip
    when 'true'
      true
    when 'false'
      false
    when 'nil', 'null'
      nil
    else
      if default.nil?
        self
      else
        default
      end
    end
  end

  def numeric default = nil
    case self
    when /^\d+([\d_]+\d+|\d*)$/
      self.to_i
    when /^\d+([\d_]+\d+|\d*)\.\d+([\d_]+\d+|\d*)$/
      self.to_f
    else
      if default.nil?
        self
      else
        default
      end
    end
  end

  def nil
    str = strip

    if str.empty? or str.downcase == 'nil' or str.downcase == 'null'
      nil
    else
      str
    end
  end

  def to_obj
    dup = self.boolean

    if dup.is_a? String
      dup = self.numeric
    end

    if dup.is_a? String
      dup = self.nil
    end

    dup
  end

  def to_json_string
    to_json
  end
end

class String
  def expand args = nil
    args ||= {}

    if self =~ /\$(\(([\w.:-]+)\)|{([\w.:-]+)})/
      val = $1[1..-2]

      case
      when args.has_key?(val)
        str = args[val]
      when args.has_key?(val.to_sym)
        str = args[val.to_sym]
      else
        str = $&
      end

      '%s%s%s' % [$`, str, $'.expand(args)]
    else
      self
    end
  end
end