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

  def package branch = nil, version = nil, http = nil, username = nil, password = nil
    branch ||= 'master'

    LOG_HEAD '开始版本打包(%s:%s) ...' % [branch, version]

    zipfile_home = '/tmp/zipfile'
    File.delete zipfile_home

    zip = Provide::Zip.new File.join(zipfile_home, 'stn_%s_%s.zip' % [branch, (version || Time.now.timestamp_day).to_s.strip.gsub(' ', '').downcase])

    if not zip.open true
      return false
    end

    repository.keys.each do |name|
      if name == 'u3_interface'
        home = File.join branch, name, 'sdn/build/output'
      else
        home = File.join branch, name, 'code/build/output'
      end

      if File.directory? home
        if not zip.add home do |file|
            puts file

            file
          end

          return false
        end
      end
    end

    if not zip.save
      return false
    end

    if not username.nil? and not password.nil?
      [
        'jfrog rt config --interactive=false --url=%s --user=%s --password=%s' % [http, username, password],
        'jfrog rt u %s stn_contoller-generic-local/stn_daily/' % File.join(zipfile_home, '*.zip')
      ].each do |cmdline|
        if not Provide::CommandLine::cmdline cmdline do |line, stdin, wait_thr|
            puts line
          end

          return false
        end
      end
    end

    true
  end

  def repository
    http_git = ENV['HTTP_GIT'].to_s.nil || 'ssh://10.41.103.20:29418/stn'
    http_svn = ENV['HTTP_SVN'].to_s.nil || 'https://10.5.72.55:8443/svn'

    {
      'u3_interface'=> File.join(http_svn, 'Interface'),
      'interface'   => File.join(http_git, 'sdn_interface'),
      'framework'   => File.join(http_git, 'sdn_framework'),
      'application' => File.join(http_git, 'sdn_application'),
      'tunnel'      => File.join(http_git, 'sdn_tunnel'),
      'e2e'         => File.join(http_git, 'SPTN-E2E'),
      'ict'         => File.join(http_git, 'CTR-ICT'),
      'installation'=> File.join(http_git, 'sdn_installation')
    }
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
      if not STN::update 'interface', branch
        status = false
      end
    end

    if not STN::compile 'interface', branch, 'pom', nil, true, false
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

  task :package, [:branch, :version, :http, :username, :password] do |t, args|
    branch = args[:branch].to_s.nil
    version = args[:version].to_s.nil
    http = args[:http].to_s.nil || (ENV['ARTIFACT_HTTP'] || 'http://artifacts.zte.com.cn/artifactory')
    username = args[:username].to_s.nil || (ENV['ARTIFACT_USERNAME'] || 'stn_contoller-ci')
    password = args[:password].to_s.nil || (ENV['ARTIFACT_PASSWORD'] || 'stn_contoller-ci*123')

    STN::package(branch, version, http, username, password).exit
  end
end
