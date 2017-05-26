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
  namespace :update do
    task :update, [:name, :branch] do |t, args|
      name = args[:name].to_s.nil
      branch = args[:branch].to_s.nil

      home = (args[:home] || ENV['BUILD_HOME']).to_s.nil || 'main'

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
  end

  namespace :compile do
    task :mvn, [:name, :dirname, :cmdline, :force, :retry] do |t, args|
      name = args[:name].to_s.nil
      dirname = args[:dirname].to_s.nil
      cmdline = args[:cmdline].to_s.nil || 'mvn deploy -fn -U'
      force = args[:force].to_s.boolean true
      _retry = args[:retry].to_s.boolean true

      home = (args[:home] || ENV['BUILD_HOME']).to_s.nil || 'main'

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
  end
end