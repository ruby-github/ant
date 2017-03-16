# ----------------------------------------------------------
#
# $packages = nil
# $package_methods = nil
# $skiperror = false
#
# ----------------------------------------------------------

module Package
  module Mixin
    module_function

    def package klass, method_name = nil
      if method_name.nil?
        description = nil
        method_name = klass.name.split(/[:.]+/).last.downcase
      else
        description = method_name
      end

      $package_methods ||= {}
      $package_methods[method_name.to_s] = klass

      define_method method_name.to_sym do |name, &block|
        pkg = klass.new name

        if not description.nil?
          pkg.description description
        end

        if block.nil?
          pkg
        else
          block.call pkg
        end
      end
    end

    def package_next?
      if not $skiperror
        $packages ||= []

        $packages.each do |pkg|
          if not pkg.success?
            return false
          end
        end
      end

      true
    end
  end

  class Info
    attr_reader :name, :starttime, :endtime
    attr_accessor :status

    def initialize name, skiperror = false
      @name = name
      @starttime = Time.now
      @endtime = nil
      @skiperror = skiperror

      @status = nil
    end

    def set_endtime
      @endtime = Time.now
    end

    def duration
      if not @endtime.nil?
        @endtime - @starttime
      else
        nil
      end
    end

    def console string
      case @status
      when nil
        LOG_CONSOLE COLOR('[SKIP] %s' % string, COLOR_YELLOW, nil, FONT_HIGHLIGHT)
      when true
        LOG_CONSOLE COLOR('[SUCCESS] %s' % string, COLOR_GREEN, nil, FONT_HIGHLIGHT)
      else
        LOG_CONSOLE COLOR('[FAIL] %s' % string, COLOR_RED, nil, FONT_HIGHLIGHT)
      end
    end

    def success?
      @skiperror or @status != false
    end

    def skip?
      @status.nil?
    end
  end

  class Package
    def initialize name
      @name = name.utf8
      @description = self.class.name.split(/[:.]+/).last.downcase
      @cwd = Dir.pwd

      @skiperror = false
      @actions = []
    end

    def description description
      @description = description.utf8
    end

    def cwd cwd
      @cwd = File.expand_path cwd
    end

    def skiperror skiperror = true
      @skiperror = skiperror.to_s.boolean true
    end

    def cmdline cmdline, args = nil
      exec :cmdline, cmdline, args do
        Provide::CommandLine::cmdline cmdline, args do |line, stdin, wait_thr|
          if block_given?
            yield line
          end
        end
      end
    end

    def success?
      if not @skiperror
        @actions.each do |info|
          if not info.success?
            return false
          end
        end
      end

      true
    end

    private

    # args
    #   skiperror
    def exec symbol, desc = nil, args = nil
      args ||= {}

      info = Info.new symbol.to_s, args[:skiperror]

      begin
        if next?
          info.status = true

          Dir.chdir @cwd do
            info.status = yield
          end
        end
      rescue
        LOG_EXCEPTION $!

        info.status = false
      ensure
        info.set_endtime

        string = [@description, symbol, @name].utf8.join '.'

        if not desc.nil?
          string = [string, desc].utf8.join ': '
        end

        @actions << info

        info.console string

        info.status
      end
    end

    def next?
      success?
    end
  end
end

include Package::Mixin

require 'ant/package/sequence'
require 'ant/package/file'
require 'ant/package/gem'
require 'ant/package/git'
require 'ant/package/host'
require 'ant/package/maven'
require 'ant/package/quicktest'
require 'ant/package/service'
require 'ant/package/svn'
require 'ant/package/zip'