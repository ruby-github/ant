module Package
  # [
  #   {
  #     :pkg      => 'service',
  #     :name     => 'ant_daemon',
  #     :ip       => '10.8.10.9',
  #     :username => nil,
  #     :args     => {
  #       :skiperror => true
  #     },
  #     :exec     => [
  #       ['file'   , ['/etc/init.d/ant_daemon']],
  #       ['source' , ['bin/daemon']],
  #       ['enable' , ['...']],
  #       ['start'  , nil],
  #       ['stop'   , nil],
  #       ['disable', nil]
  #     ]
  #   },
  #   {
  #     :parallel=>[]
  #   }
  # ]
  module SequenceExec
    module_function

    def sequence array
      status = true

      array.each do |x|
        case
        when x.is_a?(Array)
          if not sequence(x) do |line|
              if block_given?
                yield line
              end
            end

            status = false
          end
        when x.is_a?(Hash)
          if [:parallel] == x.keys
            if not parallel(x[:parallel]) do |line|
                if block_given?
                  yield line
                end
              end

              status = false
            end
          else
            if not package(x) do |line|
                if block_given?
                  yield line
                end
              end

              status = false
            end
          end
        else
        end
      end

      status
    end

    def parallel array
      status = true

      threads = []

      array.each do |x|
        case
        when x.is_a?(Array)
          threads << Thread.new do
            drb_connect nil do |drb|
              Thread.current[:drb] = drb

              if not drb.function SequenceExec, :sequence, x do |line|
                  if block_given?
                    yield line
                  end
                end

                status = false
              end
            end
          end
        when x.is_a?(Hash)
          if [:parallel] == x.keys
            threads << Thread.new do
              drb_connect nil do |drb|
                Thread.current[:drb] = drb

                if not drb.function SequenceExec, :parallel, x[:parallel] do |line|
                    if block_given?
                      yield line
                    end
                  end

                  status = false
                end
              end
            end
          else
            threads << Thread.new do
              drb_connect nil do |drb|
                Thread.current[:drb] = drb

                if not drb.function SequenceExec, :package, x do |line|
                    if block_given?
                      yield line
                    end
                  end

                  status = false
                end
              end
            end
          end
        else
        end
      end

      loop do
        alive = false

        threads.each do |thr|
          thr.join 5

          drb_loggers thr[:drb] do |line, error|
            if block_given?
              yield line
            end
          end

          if thr.alive?
            alive = true
          end
        end

        if not alive
          break
        end
      end

      status
    end

    def package hash
      ip = hash[:ip].to_s.nil
      username = hash[:username].to_s.nil

      if Socket.ip_addresses.include? ip
        ip = nil
      end

      status = true

      if ip.nil?
        pkg_name = hash[:pkg]

        if $package_methods.nil? or not $package_methods.keys.include? pkg_name
          LOG_ERROR 'undefined package: %s' % pkg_name

          return false
        end

        name = hash[:name].to_s.nil

        if name.nil?
          LOG_ERROR 'name is nil: %s' % pkg_name

          return false
        end

        pkg = $package_methods[pkg_name].new name

        (hash[:args] || {}).each do |attr_name, attr_value|
          if not pkg.respond_to? attr_name.to_s
            next
          end

          m = pkg.method attr_name

          begin
            m.call attr_value do |line|
              if block_given?
                yield line
              end
            end
          rescue
            LOG_EXCEPTION $!

            status = false
          end
        end

        (hash[:exec] || []).each do |function_name, args|
          if not pkg.respond_to? function_name.to_s
            LOG_ERROR 'undefined method: %s.%s' % [pkg.class, function_name]

            status = false

            next
          end

          m = pkg.method function_name

          begin
            if args.nil?
              if not m.call do |line|
                  if block_given?
                    yield line
                  end
                end

                status = false
              end
            else
              if not m.call *args do |line|
                  if block_given?
                    yield line
                  end
                end

                status = false
              end
            end
          rescue
            LOG_EXCEPTION $!

            status = false
          end
        end
      else
        hash.delete :ip
        hash.delete :username

        thr = Thread.new do
          drb_connect ip, username do |drb|
            Thread.current[:drb] = drb

            if not drb.function SequenceExec, :package, hash do |line|
                if block_given?
                  yield line
                end
              end

              status = false
            end
          end
        end

        loop do
          thr.join 5

          drb_loggers thr[:drb] do |line, error|
            if block_given?
              yield line
            end
          end

          if not thr.alive?
            break
          end
        end
      end

      status
    end
  end

  # [
  #   {
  #     "pkg"     : "service",
  #     "name"    : "ant_daemon",
  #     "ip"      : "10.8.10.9",
  #     "username": nil,
  #     "args"    : {
  #       "skiperror" : true
  #     },
  #     "exec"    : [
  #       ["file"   , {"file": "/etc/init.d/ant_daemon"}],
  #       ["source" , {"file": "bin/daemon"}],
  #       ["enable" , {"arg": "..."}],
  #       ["start"  , null],
  #       ["stop"   , null],
  #       ["disable", null]
  #     ]
  #   },
  #   {
  #     "parallel": []
  #   }
  # ]
  module SequenceJSON
    module_function

    def sequence array
      sequence = []

      array.each do |x|
        case
        when x.is_a?(Array)
          sequence << sequence(x)
        when x.is_a?(Hash)
          if ['parallel'] == x.keys
            sequence << parallel(x['parallel'])
          else
            sequence << package(x)
          end
        else
        end
      end

      sequence
    end

    def parallel array
      parallel = {
        :parallel => []
      }

      array.each do |x|
        case
        when x.is_a?(Array)
          parallel[:parallel] << sequence(x)
        when x.is_a?(Hash)
          if ['parallel'] == x.keys
            parallel[:parallel] << parallel(x['parallel'])
          else
            parallel[:parallel] << package(x)
          end
        else
        end
      end

      parallel
    end

    def package _hash
      pkg_name = _hash['pkg']

      if $package_methods.nil? or not $package_methods.keys.include? pkg_name
        raise 'undefined package: %s' % pkg_name
      end

      name = _hash['name'].to_s.nil

      if name.nil?
        raise 'name is nil: %s' % pkg_name
      end

      pkg = $package_methods[pkg_name].new name

      ip = _hash['ip'].to_s.nil

      if Socket.ip_addresses.include? ip
        ip = nil
      end

      hash = {
        :pkg      => pkg_name,
        :name     => name,
        :ip       => ip,
        :username => _hash['username'].to_s.nil,
        :args     => nil,
        :exec     => []
      }

      (_hash['args'] || {}).each do |k, v|
        hash[:args] ||= {}
        hash[:args][k.to_sym] = v.to_s.to_obj
      end

      (_hash['exec'] || []).each do |x|
        hash[:exec] << method(pkg, x)
      end

      hash
    end

    def method pkg, array
      name = array.first

      if not pkg.respond_to? name.to_s
        raise 'undefined method: %s.%s' % [pkg.class, name]
      end

      m = pkg.method name

      attributes = {}

      (array[1] || {}).each do |k, v|
        attributes[k.to_sym] = v.to_obj
      end

      params = {}

      m.parameters.each do |x|
        if [:block].include? x.first
          next
        end

        params[x.last] = x.first
      end

      args = nil

      params.keys.each do |x|
        args ||= {}
        args[x] = attributes[x]

        attributes.delete x
      end

      if not args.nil?
        if args.keys.last == :args
          if args[:args].nil?
            if attributes.empty?
              if [:opt].include? params[:args]
                args.delete :args
              end
            else
              args[:args] = attributes
            end
          end
        end

        if args.empty?
          args = nil
        else
          args = args.values
        end
      end

      [name, args]
    end
  end

  # <?xml version='1.0' encoding='utf-8'?>
  #
  # <sequence>
  #   <service name='ant_daemon' ip='10.8.10.9' skiperror='true'>
  #     <file file='/etc/init.d/ant_daemon'/>
  #     <source file='bin/daemon'/>
  #
  #     <enable arg='...'/>
  #     <start/>
  #     <stop/>
  #     <disable/>
  #   </service>
  #
  #   <parallel>
  #     ...
  #   </parallel>
  # </sequence>
  module SequenceXML
    module_function

    def sequence element
      sequence = []

      element.each_element do |e|
        case e.name
        when 'sequence'
          sequence << sequence(e)
        when 'parallel'
          sequence << parallel(e)
        else
          sequence << package(e)
        end
      end

      sequence
    end

    def parallel element
      parallel = {
        :parallel => []
      }

      element.each_element do |e|
        case e.name
        when 'sequence'
          parallel[:parallel] << sequence(e)
        when 'parallel'
          parallel[:parallel] << parallel(e)
        else
          parallel[:parallel] << package(e)
        end
      end

      parallel
    end

    def package element
      pkg_name = element.name

      if $package_methods.nil? or not $package_methods.keys.include? pkg_name
        raise 'undefined package: %s' % pkg_name
      end

      name = element.attributes['name'].to_s.nil

      if name.nil?
        raise 'name is nil: %s' % pkg_name
      end

      pkg = $package_methods[pkg_name].new name

      ip = element.attributes['ip'].to_s.nil

      if Socket.ip_addresses.include? ip
        ip = nil
      end

      hash = {
        :pkg      => pkg_name,
        :name     => name,
        :ip       => ip,
        :username => element.attributes['username'].to_s.nil,
        :args     => nil,
        :exec     => []
      }

      element.attributes.each do |k, v|
        if ['name', 'ip', 'username'].include? k
          next
        end

        if pkg.respond_to? k
          hash[:args] ||= {}
          hash[:args][k.to_sym] = v.to_obj
        end
      end

      element.each_element do |e|
        hash[:exec] << method(pkg, e)
      end

      hash
    end

    def method pkg, element
      name = element.name

      if not pkg.respond_to? name
        raise 'undefined method: %s.%s' % [pkg.class, name]
      end

      m = pkg.method name

      attributes = {}

      element.attributes.each do |k, v|
        attributes[k.to_sym] = v.to_obj
      end

      params = {}

      m.parameters.each do |x|
        if [:block].include? x.first
          next
        end

        params[x.last] = x.first
      end

      args = nil

      params.keys.each do |x|
        args ||= {}
        args[x] = attributes[x]

        attributes.delete x
      end

      if not args.nil?
        if args.keys.last == :args
          if args[:args].nil?
            if attributes.empty?
              if [:opt].include? params[:args]
                args.delete :args
              end
            else
              args[:args] = attributes
            end
          end
        end

        if args.empty?
          args = nil
        else
          args = args.values
        end
      end

      [name, args]
    end
  end
end

module Package
  module SequenceMixin
    module_function

    def sequence_exec sequence
      SequenceExec::sequence sequence do |line|
        if block_given?
          yield line
        end
      end
    end

    def sequence_from_json file, args = nil
      begin
        sequence = SequenceJSON::sequence JSON::parse(IO.read(file)).expand(args)

        sequence
      rescue
        LOG_EXCEPTION $!

        nil
      end
    end

    def sequence_from_xml file, args = nil
      begin
        doc = REXML::Document.file file
        doc.expand args

        sequence = []

        REXML::XPath.each doc, '/sequence' do |element|
          sequence += SequenceXML::sequence element
        end

        sequence
      rescue
        LOG_EXCEPTION $!

        nil
      end
    end
  end
end

include Package::SequenceMixin