# Ensure we require the local version and not one we might have installed already
require File.join([File.dirname(__FILE__),'lib','movier','version.rb'])
Gem::Specification.new do |s|
  s.name = 'movier'
  s.version = Movier::VERSION
  s.author = 'Nikhil Gupta'
  s.email = 'me@nikhgupta.com'
  s.homepage = 'http://nikhgupta.com'
  s.platform = Gem::Platform::RUBY
  s.summary = 'Movier is a gem that allows you to quickly organize your movies.'
  s.description = 'Movier allows you to quickly organize your movies database.'
# Add your other files here if you make them
  s.files = `git ls-files`.split
  s.require_paths << 'lib'
  s.has_rdoc = false
  s.bindir = 'bin'
  s.executables << 'movier'
  s.licenses = 'MIT'

  s.add_dependency 'json', '~> 1'
  s.add_dependency 'highline', '~> 1'
  s.add_dependency 'httparty', '~> 0'

  s.add_development_dependency 'pry', '~> 0'
  s.add_runtime_dependency 'gli','2.5.3'
end
