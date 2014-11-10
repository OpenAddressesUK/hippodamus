require 'hippodomus'
require 'vcr'
require 'pry'
require 'csv'

require 'simplecov'
SimpleCov.start

require 'coveralls'
Coveralls.wear!

ENV['MONGO_DB'] = "hippodamus_test"

Fog.mock!

VCR.configure do |c|
  c.cassette_library_dir = 'spec/cassettes'
  c.default_cassette_options = { :record => :once }
  c.hook_into :webmock
  c.configure_rspec_metadata!
end

RSpec.configure do |config|

  config.before(:all) do
    `mongoimport --db #{ENV['MONGO_DB']} --collection addresses --file spec/fixtures/adresses.json --drop`
  end

  config.after(:each) do
    `rm -r addresses/ > /dev/null 2>&1`
    Fog::Mock.reset
  end

end

def get_file(filename)
  File.join( File.dirname(__FILE__), "..", "addresses", filename )
end
