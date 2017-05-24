Gem::Specification.new do |s|
  s.name                  = 'ant'
  s.version               = '0.0.2'
  s.authors               = 'jack'
  s.date                  = '2017-03-15'
  s.summary               = 'intelligent agent'
  s.description           = 'intelligent agent'

  s.files                 = Dir.glob('{bin,lib}/**/*') + ['ant.gemspec', 'README.md']
  s.executables           = ['ant']
  s.require_path          = 'lib'
  s.required_ruby_version = '>= 2.3.0'
end