require 'rake'

$stn_repos = {
  'u3_interface'=> 'https://10.5.72.55:8443/svn/Interface',
  'interface'   => 'ssh://gerrit.zte.com.cn:29418/stn/sdn_interface',
  'framework'   => 'ssh://gerrit.zte.com.cn:29418/stn/sdn_framework',
  'application' => 'ssh://gerrit.zte.com.cn:29418/stn/sdn_application',
  'nesc'        => 'ssh://gerrit.zte.com.cn:29418/stn/sdn_nesc',
  'tunnel'      => 'ssh://gerrit.zte.com.cn:29418/stn/sdn_tunnel',
  'ict'         => 'ssh://gerrit.zte.com.cn:29418/stn/CTR-ICT',
  'e2e'         => 'ssh://gerrit.zte.com.cn:29418/stn/SPTN-E2E',
  'installation'=> 'ssh://gerrit.zte.com.cn:29418/stn/sdn_installation'
}

namespace :stn do
  namespace :update do
    task :update, [:home, :name, :branch] do |t, args|
      home = (args[:home] || ENV['BUILD_HOME']).to_s.nil || 'main'
      name = (args[:name] || ENV['BUILD_NAME']).to_s.nil
      branch = (args[:branch] || ENV['BUILD_BRANCH']).to_s.nil

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

          if not Provide::Git::update $stn_repos[name], File.join(home, name), branch: branch do |line|
              puts line
            end

            status = false
          end
        end
      end

      status.exit
    end
  end

  namespace :compile do
    task :mvn, [:home, :name, :dirname, :cmdline, :force, :retry] do |t, args|
      home = (args[:home] || ENV['BUILD_HOME']).to_s.nil || 'main'
      name = (args[:name] || ENV['BUILD_NAME']).to_s.nil
      dirname = (args[:dirname] || ENV['BUILD_DIRNAME']).to_s.nil
      cmdline = (args[:cmdline] || ENV['BUILD_CMDLINE']).to_s.nil || 'mvn deploy'
      force = (args[:force].to_s.nil || ENV['BUILD_FORCE'] == '1').to_s.boolean true
      _retry = (args[:retry].to_s.nil || ENV['BUILD_RETRY'] == '1').boolean false

      status = true

      if $stn_repos.has_key? name
        if name == 'u3_interface'
          if home.nil?
            build_home = File.join home, name, 'sdn/build'
          else
            build_home = File.join home, name, dirname
          end
        else
          if home.nil?
            build_home = File.join home, name, 'code/build'
          else
            build_home = File.join home, name, dirname
          end
        end

        maven = Provide::Maven.new
        maven.path build_home

        if _retry
          if not maven.mvn cmdline, force, nil, true do |line|
              puts line
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
          # maven.sendmail
        end
      end

      status.exit
    end
  end
end