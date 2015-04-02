$:.unshift File.join( File.dirname(__FILE__), "lib")
require 'hippodamus'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

namespace :hippodamus do
  namespace :upload do
    namespace :csv do
      desc "Export CSV with provenance"
      task :with_provenance do
        Hippodamus.perform("csv", true)
      end
      desc "Export CSV without provenance"
      task :without_provenance do
        Hippodamus.perform("csv", false)
      end
    end
    namespace :json do
      desc "Export JSON with provenance"
      task :with_provenance do
        Hippodamus.perform("json", true)
      end
      desc "Export JSON without provenance"
      task :without_provenance do
        Hippodamus.perform("json", false)
      end
    end
  end
end
