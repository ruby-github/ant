require 'tmpdir'

class Dir
  class << self
    alias __tmpdir__ tmpdir
  end

  def self.tmpdir
    dir = Dir.__tmpdir__

    if OS::name == 'windows'
      if File.directory? 'C:/'
        dir = 'C:/Temp'
      end
    end

    dir
  end
end