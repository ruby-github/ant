require 'rake'

if ENV['SENDMAIL'] == '1'
  $sendmail = true
end

module STN
  module_function

  def build name, branch = nil, dirname = nil, cmdline = nil, force = true, _retry = true, update = true, compile = true, package = true
    if update
      if not update name, branch
        return false
      end
    end

    if compile
      if not compile name, branch, dirname, cmdline, force, _retry
        return false
      end
    end

    if package
      if not package name, branch
        return false
      end
    end

    return true
  end

  def update name, branch = nil
    branch ||= 'master'

    LOG_HEAD '开始版本更新 ...'

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

    LOG_HEAD '开始版本编译 ...'

    if not ENV.has_key? 'POM_VERSION'
      if branch != 'master'
        ENV['POM_VERSION'] = branch.to_s.strip.gsub(' ', '').upcase
      end
    end

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

  def package name, branch = nil
    branch ||= 'master'

    LOG_HEAD '开始版本打包 ...'

    keys = repository.keys

    if keys.include? name
      zipfile_home = File.join 'zipfile', branch
      File.delete zipfile_home

      if name == 'u3_interface'
        home = File.join branch, name, 'sdn/build/output'
      else
        home = File.join branch, name, 'code/build/output'
      end

      if File.directory? home
        packagename = 'stn_%s_%s' % [branch, Time.now.timestamp_day]

        zip = Provide::Zip.new File.join(zipfile_home, '%s_%s.zip' % [packagename, name])

        if not zip.open true
          return false
        end

        if not zip.add home, packagename do |file|
            puts file

            file
          end

          return false
        end

        if not zip.save
          return false
        end

        true
      else
        LOG_ERROR 'no such directory: %s' % File.expand_path(home)

        false
      end
    else
      LOG_ERROR 'name not found in %s' % repos.keys.to_s

      false
    end
  end

  def repository
    http_git = ENV['HTTP_GIT'].to_s.nil || 'ssh://10.41.103.20:29418/stn'
    http_svn = ENV['HTTP_SVN'].to_s.nil || 'https://10.5.72.55:8443/svn'

    {
      'u3_interface'=> File.join(http_svn, 'Interface'),
      'interface'   => File.join(http_git, 'sdn_interface'),
      'framework'   => File.join(http_git, 'sdn_framework'),
      'application' => File.join(http_git, 'sdn_application'),
      'nesc'        => File.join(http_git, 'sdn_nesc'),
      'tunnel'      => File.join(http_git, 'sdn_tunnel'),
      'ict'         => File.join(http_git, 'CTR-ICT'),
      'e2e'         => File.join(http_git, 'SPTN-E2E'),
      'installation'=> File.join(http_git, 'sdn_installation')
    }
  end
end

namespace :stn do
  task :build, [:name, :branch, :dirname, :cmdline, :force, :retry, :update, :compile, :package] do |t, args|
    name = args[:name].to_s.nil
    branch = args[:branch].to_s.nil
    dirname = args[:dirname].to_s.nil
    cmdline = args[:cmdline].to_s.nil
    force = args[:force].to_s.boolean true
    _retry = args[:retry].to_s.boolean true

    update = args[:update].to_s.boolean true
    compile = args[:compile].to_s.boolean true
    package = args[:package].to_s.boolean true

    STN::build(name, branch, dirname, cmdline, force, _retry, update, compile, package).exit
  end

  task :parent, [:branch] do |t, args|
    branch = args[:branch].to_s.nil

    (STN::update 'interface', branch and STN::compile 'interface', branch, 'pom', nil, true, false).exit
  end
end
