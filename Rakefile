$:.unshift File.join( File.dirname(__FILE__), "lib")
require 'hippodamus'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

namespace :hippodamus do
  task :upload do
    Hippodamus.perform
  end
end
