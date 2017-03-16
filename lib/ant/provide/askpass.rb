module Provide
  module AskPass
    module_function

    def set_askpass key
      if OS::name == 'windows'
        filename = File.join Ant::HOME, 'bin', 'askpass.exe'
      else
        filename = File.join Ant::HOME, 'bin', 'askpass'
      end

      File.chmod 0777, filename

      ENV[key] = filename
    end

    def askpass value
      File.open File.join(ENV['HOME'], '.askpass'), 'w' do |file|
        file.puts value
      end
    end
  end
end