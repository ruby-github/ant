require 'fiddle'

module OS
  module_function

  def name
    case RbConfig::CONFIG['host_os']
    when /mswin|mingw|cygwin/
      'windows'
    when /linux/
      'linux'
    when /solaris/
      'solaris'
    when /freebsd|openbsd|netbsd/
      'bsd'
    when /darwin/
      'mac'
    when /hpux/
      'hpux'
    when /aix/
      'aix'
    else
      RbConfig::CONFIG['host_os']
    end
  end

  def user_process cmdline, async = false, username = nil
    if name == 'windows'
      begin
        dll = Fiddle::dlopen File.join Ant::HOME, 'bin/function.dll'
        func = Fiddle::Function.new dll['create_user_process'], [Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT], Fiddle::TYPE_INT

        if 0 == func.call(cmdline.locale, async.to_i)
          dll.close

          true
        else
          dll.close

          false
        end
      rescue
        LOG_EXCEPTION $!

        false
      end
    else
      if not username.nil?
        cmdline = "su - %s -c '%s'" % [username, cmdline].locale
      end

      Provide::CommandLine::cmdline cmdline, async: async
    end
  end
end