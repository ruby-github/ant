class Object
  alias __clone__ clone
  alias __dup__ dup

  def clone
    begin
      __clone__
    rescue
      self
    end
  end

  def dup
    begin
      __dup__
    rescue
      self
    end
  end

  def dclone
    dup = clone

    self.instance_variables.each do |x|
      dup.instance_variable_set x, self.instance_variable_get(x).dclone
    end

    dup
  end
end

class Object
  def locale
    dup = dclone

    dup.instance_variables.each do |x|
      dup.instance_variable_set x, dup.instance_variable_get(x).locale
    end

    dup
  end

  def utf8
    dup = dclone

    dup.instance_variables.each do |x|
      dup.instance_variable_set x, dup.instance_variable_get(x).utf8
    end

    dup
  end

  def to_array
    [self]
  end

  def to_i
    0
  end

  def to_string
    to_s.utf8
  end

  def to_json_string
    to_json
  end
end

class Object
  def expand args = nil
    self
  end
end