module Provide
  module Gem
    module_function

    def install name
      if File.file? name
        Dir.chdir File.dirname(name) do
          cmdline = 'gem install %s --local' % File.basename(name)

          CommandLine::cmdline cmdline do |line, stdin, wait_thr|
            if block_given?
              yield line
            end
          end
        end
      else
        cmdline = 'gem install %s' % name

        CommandLine::cmdline cmdline do |line, stdin, wait_thr|
          if block_given?
            yield line
          end
        end
      end
    end

    def uninstall name
      name = File.basename name, '.*'

      if name =~ /-[\d.]+$/
        name = $`
      end

      cmdline = 'gem uninstall %s' % name

      CommandLine::cmdline cmdline do |line, stdin, wait_thr|
        if block_given?
          yield line
        end
      end
    end
  end
end