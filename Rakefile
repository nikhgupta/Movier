require 'rubygems'
require 'rubygems/package_task'

spec = eval(File.read('movier.gemspec'))
Gem::PackageTask.new(spec){}

task :default => :test
