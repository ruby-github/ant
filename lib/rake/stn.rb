require 'rake'

$stn_repos = {
  'u3_interface'=> 'https://10.5.72.55:8443/svn/Interface',
  'interface'   => 'ssh://10.41.103.20:29418/stn/sdn_interface',
  'framework'   => 'ssh://10.41.103.20:29418/stn/sdn_framework',
  'application' => 'ssh://10.41.103.20:29418/stn/sdn_application',
  'nesc'        => 'ssh://10.41.103.20:29418/stn/sdn_nesc',
  'tunnel'      => 'ssh://10.41.103.20:29418/stn/sdn_tunnel',
  'ict'         => 'ssh://10.41.103.20:29418/stn/CTR-ICT',
  'e2e'         => 'ssh://10.41.103.20:29418/stn/SPTN-E2E',
  'installation'=> 'ssh://10.41.103.20:29418/stn/sdn_installation'
}

namespace :stn do
  task :update, [:name, :branch] do |t, args|
    name = args[:name].to_s.nil
    branch = args[:branch].to_s.nil

    home = ENV['BUILD_HOME'].to_s.nil || 'main'

    status = true

    if $stn_repos.has_key? name
      if name == 'u3_interface'
        if branch.nil?
          branch = 'trunk'
        else
          if branch == File.basename(branch)
            branch = File.join 'branches', branch
          end
        end

        ['code/asn', 'sdn'].each do |dirname|
          if not Provide::Svn::update File.join($stn_repos[name], branch, dirname),
            File.join(home, name, dirname), username: 'u3build', password: 'u3build' do |line|
              puts line
            end

            status = false
          end
        end
      else
        if branch.nil?
          branch = 'master'
        end

        if not Provide::Git::update $stn_repos[name], File.join(home, name), branch: branch, username: 'u3build' do |line|
            puts line
          end

          status = false
        end
      end
    else
      LOG_ERROR 'name not found in %s' % $stn_repos.to_s

      status = false
    end

    status.exit
  end

  task :compile, [:name, :dirname, :cmdline, :force, :retry] do |t, args|
    name = args[:name].to_s.nil
    dirname = args[:dirname].to_s.nil
    cmdline = args[:cmdline].to_s.nil || 'mvn deploy -fn -U'
    force = args[:force].to_s.boolean true
    _retry = args[:retry].to_s.boolean true

    home = ENV['BUILD_HOME'].to_s.nil || 'main'

    status = true

    if $stn_repos.has_key? name
      if name == 'u3_interface'
        if dirname.nil?
          build_home = File.join home, name, 'sdn/build'
        else
          build_home = File.join home, name, dirname
        end
      else
        if dirname.nil?
          build_home = File.join home, name, 'code/build'
        else
          build_home = File.join home, name, dirname
        end
      end

      maven = Provide::Maven.new
      maven.path build_home

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
    else
      LOG_ERROR 'name not found in %s' % $stn_repos.to_s

      status = false
    end

    status.exit
  end

  task :install do |t, args|
    home = ENV['BUILD_HOME'].to_s.nil || 'main'

    status = true

    if File.directory? home
      tmpdir = File.join 'output', File.tmpname

      $stn_repos.keys.each do |name|
        if name == 'u3_interface'
          output_home = File.join home, name, 'sdn/build/output'
        else
          output_home = File.join home, name, 'code/build/output'
        end

        if not File.directory? output_home
          LOG_ERROR 'no such directory: %s' % File.expand_path(output_home)

          status = false

          break
        end

        if not File.copy output_home, tmpdir do |file|
            puts file

            file
          end

          status = false

          break
        end
      end

      if status
        if File.directory? tmpdir
          filename = File.expand_path 'stn_%s_%s.tar.gz' % [File.basename(home), Time.timestamp_day]

          Dir.chdir tmpdir do
            if not Provide::CommandLine::cmdline 'tar vczf %s *' % File.cmdline(tmpdir) do |line|
                puts line
              end

              status = false
            end
          end
        end
      end

      File.delete tmpdir
    else
      LOG_ERROR 'no such directory: %s' % File.expand_path(home)

      status = false
    end

    status.exit
  end
end