require 'ant/ant'
require 'ant/core'
require 'ant/os'
require 'ant/package'
require 'ant/provide'
require 'ant/util'

require 'rake/stn'

module Ant
  HOME = File.dirname File.dirname(__FILE__)
end

def drb_connect ip, username = nil
  drb = Ant::Object.new

  begin
    if drb.connect ip, nil, username
      if block_given?
        yield drb
      else
        true
      end
    else
      false
    end
  rescue
    LOG_EXCEPTION $!

    false
  ensure
    drb_loggers drb do |line, error|
      if error
        $errors ||= []
        $errors << line
      else
        $loggers ||= []
        $loggers << line
      end
    end

    drb.close
  end
end

def drb_loggers drb
  begin
    loggers = drb.loggers

    if not loggers.nil?
      loggers.each do |line|
        if block_given?
          yield line, false
        end
      end
    end

    errors = drb.errors

    if not errors.nil?
      errors.each do |line|
        if block_given?
          yield line, true
        end
      end
    end
  rescue
  end
end