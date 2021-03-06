require 'webmock/rspec'
require 'vcr'
require 'pry'
require 'csv'
require 'timecop'
require 'factory_girl'
require 'database_cleaner'

ENV['MONGOID_ENVIRONMENT'] = "test"
ENV['JQ'] ||= "/usr/local/bin/jq"

require 'hippodamus'

require 'simplecov'
SimpleCov.start

require 'coveralls'
Coveralls.wear!

Fog.mock!

VCR.configure do |c|
  c.ignore_localhost = true
  c.cassette_library_dir = 'spec/cassettes'
  c.default_cassette_options = { :record => :once }
  c.hook_into :webmock
  c.configure_rspec_metadata!
end

RSpec.configure do |config|
  config.include FactoryGirl::Syntax::Methods
  FactoryGirl.definition_file_paths = ["#{Gem.loaded_specs['mongoid_address_models'].full_gem_path}/lib/mongoid_address_models/factories", "./spec/factories"]
  FactoryGirl.find_definitions

  config.before(:suite) do
    DatabaseCleaner[:mongoid].strategy = :truncation
    DatabaseCleaner[:mongoid].clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    `rm -r /tmp/addresses/ > /dev/null 2>&1`
    DatabaseCleaner.clean
  end

  config.before(:example, :fog) do
    Fog.mock!
    allow(Hippodamus).to receive(:connection).and_return(Fog::Storage.new({
      :aws_access_key_id      => 'fake_access_key_id',
      :aws_secret_access_key  => 'fake_secret_access_key',
      :provider               => 'AWS',
      :region                 => 'eu-west-1'
    }))

    @connection = Hippodamus.connection
    @directory = @connection.directories.create(
      key: ENV['AWS_BUCKET'],
      public: true
    )

    Hippodamus.export("WS")

    Hippodamus.zip_by_letter("csv", false)
    Hippodamus.zip_all("csv", false)
  end

  config.after(:example, :fog) do
    Fog::Mock.reset
    Fog.unmock!
  end

end

def get_file(filename, with_provenance)
  File.join( "/", "tmp", "addresses", with_provenance.to_s, filename )
end
