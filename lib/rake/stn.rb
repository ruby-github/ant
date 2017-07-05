require 'rake'

if ENV['SENDMAIL'] == '1'
  $sendmail = true
end

module STN
  module_function

  def update name, branch = nil
    branch ||= 'master'

    LOG_HEAD '开始版本更新(%s:%s) ...' % [name, branch]

    repos = repository

    if repos.has_key? name
      if name == 'u3_interface'
        if branch == 'master'
          http = File.join repos[name], 'trunk'
        else
          http = File.join repos[name], 'branches', branch
        end

        ['code/asn', 'sdn'].each do |dirname|
          if not Provide::Svn::update File.join(http, dirname), File.join(branch, name, dirname), username: 'u3build', password: 'u3build' do |line|
              puts line
            end

            File.delete File.join(branch, name, dirname)

            return false
          end
        end
      else
        if not Provide::Git::update repos[name], File.join(branch, name), branch: branch, username: 'u3build' do |line|
            puts line
          end

          File.delete File.join(branch, name)

          return false
        end
      end

      true
    else
      LOG_ERROR 'name not found in %s' % repos.keys.to_s

      false
    end
  end

  def compile name, branch = nil, dirname = nil, cmdline = nil, force = true, _retry = true
    branch ||= 'master'
    cmdline ||= 'mvn deploy -fn -U'

    LOG_HEAD '开始版本编译(%s:%s) ...' % [name, branch]

    keys = repository.keys

    if keys.include? name
      if name == 'u3_interface'
        if dirname.nil?
          home = File.join branch, name, 'sdn/build'
        else
          home = File.join branch, name, dirname
        end
      else
        if dirname.nil?
          home = File.join branch, name, 'code/build'
        else
          home = File.join branch, name, dirname
        end
      end

      maven = Provide::Maven.new
      maven.path home

      status = true

      if _retry
        if not maven.mvn cmdline, force, nil, true do |line|
            if not maven.ignore
              puts line
            end
          end

          if not maven.mvn_retry cmdline do |line|
              puts line
            end

            status = false
          end
        end
      else
        if not maven.mvn cmdline, force do |line|
            puts line
          end

          status = false
        end
      end

      if not status
        maven.puts_errors
        maven.sendmail
      end

      status
    else
      LOG_ERROR 'name not found in %s' % repos.keys.to_s

      false
    end
  end

  def package branch = nil, version = nil, nfm_version = nil, http = nil, username = nil, password = nil
    LOG_HEAD '开始版本打包(%s:%s) ...' % [branch, version]

    if not Install::install branch, version, nfm_version, http, username, password
      return false
    end

    true
  end

  def repository
    http_git = ENV['HTTP_GIT'].to_s.nil || 'ssh://10.41.103.20:29418/stn'
    http_svn = ENV['HTTP_SVN'].to_s.nil || 'https://10.5.72.55:8443/svn'

    {
      'u3_interface'=> File.join(http_svn, 'Interface'),
      'sdn_interface'   => File.join(http_git, 'sdn_interface'),
      'sdn_framework'   => File.join(http_git, 'sdn_framework'),
      'sdn_application' => File.join(http_git, 'sdn_application'),
      'sdn_tunnel'      => File.join(http_git, 'sdn_tunnel'),
      'sdn_e2e'         => File.join(http_git, 'SPTN-E2E'),
      'sdn_ict'         => File.join(http_git, 'CTR-ICT'),
      'sdn_installation'=> File.join(http_git, 'sdn_installation')
    }
  end

  module Artifact
    module_function

    def config http = nil, username = nil, password = nil
      http ||= ENV['ARTIFACT_HTTP'] || 'http://artifacts.zte.com.cn/artifactory'
      username ||= ENV['ARTIFACT_USERNAME'] || 'stn_contoller-ci'
      password ||= ENV['ARTIFACT_PASSWORD'] || 'stn_contoller-ci*123'

      cmdline = 'jfrog rt config --interactive=false --url=%s --user=%s --password=%s' % [http, username, password]

      if not Provide::CommandLine::cmdline cmdline do |line, stdin, wait_thr|
          puts line
        end

        return false
      end

      return true
    end

    def upload path, to_path, http = nil, username = nil, password = nil
      if File.directory? path
        Dir.chdir File.dirname(path) do
          if not config http, username, password
            return false
          end

          cmdline = 'jfrog rt u %s/ %s/' % [File.basename(path), to_path]

          if not Provide::CommandLine::cmdline cmdline do |line, stdin, wait_thr|
              puts line
            end

            return false
          end

          true
        end
      else
        LOG_ERROR 'no such directory: %s' % path

        false
      end
    end

    def copy path, to_path, http = nil, username = nil, password = nil
      if not config http, username, password
        return false
      end

      cmdline = 'jfrog rt cp %s/ %s/' % [path, to_path]

      if not Provide::CommandLine::cmdline cmdline do |line, stdin, wait_thr|
          puts line
        end

        return false
      end

      true
    end
  end

  module Install
    module_function

    def install branch = nil, version = nil, nfm_version = nil, http = nil, username = nil, password = nil
      branch ||= 'master'

      if version.nil?
        version = 'daily_%s_%s' % [branch.downcase, Time.now.timestamp_day]
        upload_path = File.join 'snapshot', version
      else
        version = version.upcase.gsub ' ', ''
        upload_path = File.join 'alpha', version
      end

      map = installdisk File.join(branch, 'sdn_installation')
      installation = '/tmp/installation'

      if not zip map, installation, version
        return false
      end

      if not upload_nfm nfm_version, upload_path, http, username, password
        return false
      end

      if not upload installation, upload_path, http, username, password
        return false
      end

      true
    end

    def upload_nfm path = nil, to_path = nil, http = nil, username = nil, password = nil
      Artifact::copy File.join('release/nfm', path || 'default'), to_path, http, username, password
    end

    def upload path, to_path, http = nil, username = nil, password = nil
      Artifact::upload path, to_path, http, username, password
    end

    def installdisk home
      map = {}

      if File.directory? home
        Dir.chdir home do
          begin
            doc = REXML::Document.file 'installdisk/installdisk.xml'
          rescue
            LOG_EXCEPTION $!

            return nil
          end

          REXML::XPath.each doc, '/install/stn/packages/package' do |e|
            package = e.attributes['name'].to_s.nil
            dirname = e.attributes['dirname'].to_s.nil

            if package.nil? or dirname.nil?
              next
            end

            dirname = convert dirname

            if File.directory? dirname
              Dir.chdir dirname do
                list = []

                REXML::XPath.each e, 'file' do |element|
                  path = element.attributes['name'].to_s.nil

                  if path.nil?
                    next
                  end

                  file_dirname, filename = File.pattern_split path

                  if file_dirname.nil?
                    list << filename

                    if File.directory? filename
                      list += File.glob File.join(filename, '**/*')
                    end
                  else
                    if filename == '*'
                      filename = '**/*'
                    end

                    if file_dirname == '.'
                      xpath = filename
                    else
                      xpath = File.join file_dirname, filename

                      list << file_dirname
                    end

                    list += File.glob xpath
                  end
                end

                REXML::XPath.each e, 'ignore' do |element|
                  path = element.attributes['name'].to_s.nil

                  if path.nil?
                    next
                  end

                  file_dirname, filename = File.pattern_split path

                  if file_dirname.nil?
                    list.delete filename

                    if File.directory? filename
                      list -= File.glob File.join(filename, '**/*')
                    end
                  else
                    if filename == '*'
                      filename = '**/*'
                    end

                    if file_dirname == '.'
                      xpath = filename
                    else
                      xpath = File.join file_dirname, filename

                      list.delete file_dirname
                    end

                    list -= File.glob xpath
                  end
                end

                if not list.empty?
                  map[package] ||= {}
                  map[package][Dir.pwd] ||= []
                  map[package][Dir.pwd] += list
                end
              end
            end
          end

          map.each do |package, dirname_info|
            dirname_info.each do |dirname, list|
              list.sort!
              list.uniq!
            end
          end
        end
      end

      map
    end

    def zip map, installation, version
      if map.nil?
        return false
      end

      if File.directory? installation
        File.delete installation
      end

      map.each do |package, dirname_info|
        zipfile = Provide::Zip.new File.join(installation, 'packages', '%s_%s.zip' % [package, version])

        if not zipfile.open true
          return false
        end

        dirname_info.each do |dirname, list|
          if File.directory? dirname
            Dir.chdir dirname do
              list.each do |file|
                if File.file? file
                  if not zipfile.add expandname(file, version), file
                    return false
                  end
                else
                  if not zipfile.mkdir file
                    return false
                  end
                end
              end
            end
          end
        end

        if not zipfile.save
          return false
        end
      end
    end

    def expandname file, version
      if ['ppuinfo.xml', 'pmuinfo.xml'].include? File.basename(file).downcase
        if not file.include? '/procs/ppus/uca.ppu'
          begin
            doc = REXML::Document.file file

            REXML::XPath.each(doc, '/ppu/info | /pmu/info') do |e|
              e.attributes['version'] = version.to_s
              e.attributes['display-version'] = version.to_s
            end

            filename = File.join '/tmp/xml', File.tmpname, File.basename(file)

            doc.to_file filename

            filename
          rescue
            LOG_EXCEPTION $!

            file
          end
        else
          file
        end
      else
        file
      end
    end

    def convert dirname
      dirname.gsub! '\\', '/'
      dirname.gsub! '/trunk/', '/'

      if dirname =~ /^\.\.\/\.\.\//
        dirname = File.join '..', $'
      end

      dirname.gsub! '/SPTN-E2E/', '/sdn_e2e/'
      dirname.gsub! '/CTR-ICT/', '/sdn_ict/'

      dirname
    end
  end
end

namespace :stn do
  task :base, [:branch, :update, :version] do |t, args|
    branch = args[:branch].to_s.nil
    update = args[:update].to_s.boolean false
    version = args[:version].to_s.nil

    if not version.nil?
      ENV['POM_VERSION'] = version.gsub(' ', '').upcase
    end

    status = true

    if update
      if not STN::update 'sdn_interface', branch
        status = false
      end
    end

    if not STN::compile 'sdn_interface', branch, 'pom', nil, true, false
      status = false
    end

    status.exit
  end

  task :update, [:name, :branch] do |t, args|
    name = args[:name].to_s.nil
    branch = args[:branch].to_s.nil

    STN::update(name, branch).exit
  end

  task :compile, [:name, :branch, :dirname, :cmdline, :force, :retry, :version] do |t, args|
    name = args[:name].to_s.nil
    branch = args[:branch].to_s.nil
    dirname = args[:dirname].to_s.nil
    cmdline = args[:cmdline].to_s.nil
    force = args[:force].to_s.boolean true
    _retry = args[:retry].to_s.boolean true
    version = args[:version].to_s.nil

    if not version.nil?
      ENV['POM_VERSION'] = version.gsub(' ', '').upcase
    end

    STN::compile(name, branch, dirname, cmdline, force, _retry).exit
  end

  task :package, [:branch, :version, :nfm_version, :http, :username, :password] do |t, args|
    branch = args[:branch].to_s.nil
    version = args[:version].to_s.nil
    nfm_version = args[:nfm_version].to_s.nil
    http = args[:http].to_s.nil
    username = args[:username].to_s.nil
    password = args[:password].to_s.nil

    STN::package(branch, version, nfm_version, http, username, password).exit
  end
end
