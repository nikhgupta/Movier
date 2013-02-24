# Ensure we require the local version and not one we might have installed already
require File.join([File.dirname(__FILE__),'lib','movier','version.rb'])
Gem::Specification.new do |s| 
  s.name = 'movier'
  s.version = Movier::VERSION
  s.author = 'Nikhil Gupta'
  s.email = 'me@nikhgupta.com'
  s.homepage = 'http://nikhgupta.com'
  s.platform = Gem::Platform::RUBY
  s.summary = 'Movier is a gem that allows you to quickly organize your movies'
  s.description = 'Movier is a gem that allows you to quickly organize your movies'
# Add your other files here if you make them
  s.files = `git ls-files`.split
  s.require_paths << 'lib'
  s.has_rdoc = true
  s.extra_rdoc_files = ['README.rdoc','movier.rdoc']
  s.rdoc_options << '--title' << 'movier' << '--main' << 'README.rdoc' << '-ri'
  s.bindir = 'bin'
  s.executables << 'movier'

  s.add_dependency 'json'
  s.add_dependency 'highline'
  s.add_dependency 'httparty'

  s.add_development_dependency 'pry'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rdoc'
  s.add_development_dependency 'aruba'

  s.add_runtime_dependency 'gli','2.5.3'
end
