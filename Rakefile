$:.unshift File.join( File.dirname(__FILE__), "lib")
require 'hippodamus'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

namespace :hippodamus do
  namespace :upload do
    namespace :split do
      namespace :csv do
        desc "Export split CSV with provenance"
        task :with_provenance do
          Hippodamus.perform("csv", true)
        end
        desc "Export split CSV without provenance"
        task :without_provenance do
          Hippodamus.perform("csv", false)
        end
      end
      namespace :json do
        desc "Export split JSON with provenance"
        task :with_provenance do
          Hippodamus.perform("json", true)
        end
        desc "Export split JSON without provenance"
        task :without_provenance do
          Hippodamus.perform("json", false)
        end
      end
    end
    namespace :unified do
      namespace :csv do
        desc "Export unified CSV with provenance"
        task :with_provenance do
          Hippodamus.perform("csv", true, false)
        end
        desc "Export unified CSV without provenance"
        task :without_provenance do
          Hippodamus.perform("csv", false, false)
        end
      end
      namespace :json do
        desc "Export unified JSON with provenance"
        task :with_provenance do
          Hippodamus.perform("json", true, false)
        end
        desc "Export split JSON without provenance"
        task :without_provenance do
          Hippodamus.perform("json", false, false)
        end
      end
    end
  end
end
