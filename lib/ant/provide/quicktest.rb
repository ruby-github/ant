module Provide
  class QuickTest
    RESULTS_FILENAME = 'results.yml'

    def initialize
      @active_addins = ['java']

      @settings_resources_libraries = []
      @settings_recovery = {}
      @settings_run = {
        :iteration_mode   => 'rngAll',
        :start_iteration  => 1,
        :end_iteration    => 1,
        :on_error         => 'NextStep'
      }

      @results_location = nil
      @results_filename = 'results.yml'
    end

    def active_addins addin_names
      @active_addins = addin_names.to_array.sort.uniq
    end

    def settings_resources_libraries libs
      @settings_resources_libraries = []

      libs.to_array.each do |library_xpath|
        File.glob(library_xpath).each do |lib|
          @settings_resources_libraries << File.expand_path(lib)
        end
      end

      @settings_resources_libraries.sort!
      @settings_resources_libraries.uniq!
    end

    def settings_recovery recoverys
      @settings_recovery = {}

      recoverys.each do |file, name|
        @settings_recovery[File.expand_path(file)] = name
      end
    end

    def settings_run args
      if args.has_key? :iteration_mode
        @settings_run[:iteration_mode] = args[:iteration_mode]
      end

      if args.has_key? :start_iteration
        @settings_run[:start_iteration] = args[:start_iteration]
      end

      if args.has_key? :end_iteration
        @settings_run[:end_iteration] = args[:end_iteration]
      end

      if args.has_key? :on_error
        @settings_run[:on_error] = args[:on_error]
      end
    end

    def results_location location
      if location.nil?
        @results_location = nil
      else
        @results_location = File.expand_path location
      end
    end

    def java_table_external_editors list
      application = open

      if application.nil?
        return false
      end

      begin
        application.Launch
        application.Options.Java.TableExternalEditors = list.to_array.sort.uniq.join ' '
        application.Quit

        application = nil

        true
      rescue
        LOG_EXCEPTION $!
        LOG_ERROR 'set quicktest java tableexternaleditors fail'

        close application

        application = nil

        false
      end
    end

    def execute path, expired = nil
      path = File.expand_path path

      if expired.nil?
        expired = 3600
      else
        expired = expired.to_i
      end

      if not valid? path
        LOG_ERROR 'no such file: %s' % File.join(path, 'Action1/Script.mts')

        return false
      end

      application = open

      if application.nil?
        return false
      end

      test = nil

      begin
        if application.Launched
          application.Quit
        end

        # active addins
        if not @active_addins.nil?
          application.SetActiveAddins @active_addins, 'set active addins fail'
        end

        # launch
        application.Launch
        application.Visible = true
        application.Options.Run.RunMode = 'Fast'
        application.Open path, false, false

        # test
        sleep 3
        test = application.Test
        sleep 3

        # settings resources libraries
        test.Settings.Resources.Libraries.RemoveAll

        @settings_resources_libraries.each do |lib|
          test.Settings.Resources.Libraries.Add lib, -1
        end

        test.Settings.Resources.Libraries.SetAsDefault

        # settings recovery
        test.Settings.Recovery.RemoveAll

        @settings_recovery.each do |file, name|
          test.Settings.Recovery.Add file, name, -1
        end

        test.Settings.Recovery.Count.times do |i|
          test.Settings.Recovery.Item(i + 1).Enabled = true
        end

        test.Settings.Recovery.Enabled = true
        test.Settings.Recovery.SetActivationMode 'OnEveryStep'
        test.Settings.Recovery.SetAsDefault

        # settings run
        if not @settings_run[:iteration_mode].nil?
          test.Settings.Run.IterationMode = @settings_run[:iteration_mode]
        end

        if not @settings_run[:start_iteration].nil?
          test.Settings.Run.StartIteration = @settings_run[:start_iteration].to_i
        end

        if not @settings_run[:end_iteration].nil?
          test.Settings.Run.EndIteration = @settings_run[:end_iteration].to_i
        end

        if not @settings_run[:on_error].nil?
          test.Settings.Run.OnError = @settings_run[:on_error]
        end

        test.Save
        sleep 3

        # run_results_options
        run_results_options = WIN32OLE.new 'QuickTest.RunResultsOptions'

        if not @results_location.nil?
          run_results_options.ResultsLocation = @results_location
        end

        sleep 3
        test.Run run_results_options, false, nil
        sleep 3

        last_run_results = {
          'index'     => nil,
          'begin'     => Time.now,
          'end'       => nil,
          'passed'    => nil,
          'failed'    => nil,
          'warnings'  => nil,
          'location'  => nil,
          'expired'   => false,
          'execute'   => true,
          'compare'   => nil
        }

        while test.IsRunning
          duration = Time.now - last_run_results['begin']

          if expired > 0 and duration > expired
            test.Stop

            last_run_results['expired'] = true

            LOG_ERROR 'quicktest execution expired: %s' % [expired, path].utf8.join(', ')
          end

          sleep 1
        end

        if block_given?
          yield test
        end

        last_run_results['location'] = test.LastRunResults.Path

        if test.LastRunResults.Status != 'Passed'
          if last_run_results['expired']
            last_run_results['execute'] = nil
          else
            last_run_results['execute'] = false
          end
        end

        test.Close
        application.Quit

        last_run_results['end'] = Time.now

        begin
          doc = REXML::Document.file File.join(last_run_results['location'], 'Report/Results.xml')

          REXML::XPath.each(doc, '/Report/Doc/Summary') do |e|
            last_run_results['passed'] = e.attributes['passed'].to_i
            last_run_results['failed'] = e.attributes['failed'].to_i
            last_run_results['warnings'] = e.attributes['warnings'].to_i

            break
          end
        rescue
        end

        File.open File.join(last_run_results['location'], '..', RESULTS_FILENAME), 'w:utf-8' do |file|
          file.puts last_run_results.to_yaml
        end

        last_run_results['execute']
      rescue
        if not test.nil?
          begin
            if test.IsRunning
              test.Stop
            end

            test.Close
          rescue
          end
        end

        close application

        application = nil

        false
      end
    end

    private

    def valid? path
      if File.file? File.join(path, 'Action1/Script.mts')
        true
      else
        false
      end
    end

    def open
      application = nil

      begin
        WIN32OLE.ole_initialize

        application = WIN32OLE.new 'QuickTest.Application'
        sleep 3
      rescue
        if execute_quicktest_exe
          begin
            application = WIN32OLE.new 'QuickTest.Application'
            sleep 3
          rescue
            LOG_EXCEPTION $!
            LOG_ERROR 'create WIN32OLE QuickTest.Application fail'

            application = nil
          end
        else
          application = nil
        end
      end

      application
    end

    def close application
      if not application.nil?
        begin
          if application.Launched
            application.Test.Stop
            application.Test.Close
            application.Quit
          end
        rescue
          kill_quicktest
        ensure
          begin
            application.ole_free
          rescue
          end

          GC.start
          sleep 3
        end
      end

      true
    end

    def execute_quicktest_exe
      file = nil

      begin
        Win32::Registry::HKEY_LOCAL_MACHINE.open 'SOFTWARE\Mercury Interactive\QuickTest Professional\CurrentVersion' do |reg|
          file = File.join reg['QuickTest Professional'], 'bin', 'QTPro.exe'
        end
      rescue
      end

      if file.nil?
        begin
          Win32::Registry::HKEY_LOCAL_MACHINE.open 'SOFTWARE\Wow6432Node\Mercury Interactive\QuickTest Professional\CurrentVersion' do |reg|
            file = File.join reg['QuickTest Professional'], 'bin', 'UFT.exe'
          end
        rescue
        end
      end

      if File.file? file
        begin
          system File.cmdline(file)

          kill_quicktest

          true
        rescue
          false
        end
      else
        LOG_ERROR 'no such file: %s' % (file || 'qtpro.exe')

        false
      end
    end

    def kill_quicktest
      OS::kill do |pid, info|
        ['QTAutomationAgent.exe', 'QtpAutomationAgent.exe', 'QTPro.exe', 'UFT.exe'].include? info[:name]
      end

      true
    end
  end
end