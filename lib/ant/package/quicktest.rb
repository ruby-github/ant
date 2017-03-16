module Package
  class QuickTest < Package
    Mixin::package self

    def initialize name
      super name

      @provide = Provide::QuickTest.new
    end

    def active_addins addin_names
      @provide.active_addins addin_names
    end

    def settings_resources_libraries libs
      @provide.settings_resources_libraries libs
    end

    def settings_recovery recoverys
      @provide.settings_recovery recoverys
    end

    def settings_run args
      @provide.settings_run args
    end

    def results_location location
      @provide.results_location location
    end

    def java_table_external_editors list, args = nil
      list = list.to_array.sort.uniq

      exec :java_table_external_editors, list.join(', '), args do
        @provide.java_table_external_editors list
      end
    end

    def execute path, expired = nil, args = nil
      exec :execute, path, args do
        @provide.execute path, expired
      end
    end
  end
end