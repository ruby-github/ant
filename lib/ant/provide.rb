require 'ant/provide/askpass'
require 'ant/provide/code_count'
require 'ant/provide/command_line'
require 'ant/provide/file'
require 'ant/provide/gem'
require 'ant/provide/git'
require 'ant/provide/host'
require 'ant/provide/maven'
require 'ant/provide/quicktest'
require 'ant/provide/service'
require 'ant/provide/svn'
require 'ant/provide/zip'

autoload :WIN32OLE, 'win32ole'

module Win32
  autoload :Registry, 'win32/registry'
end

module Zip
  autoload :File, 'zip'
end