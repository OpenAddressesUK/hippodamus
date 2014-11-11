require 'hippodamus'
require 'vcr'
require 'pry'
require 'csv'
require 'timecop'

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
    `rm -r /tmp/addresses/ > /dev/null 2>&1`
  end

  config.before(:example, :fog) do
    Fog.mock!
    allow(Hippodamus).to receive(:connection).and_return(Fog::Storage.new({
      :aws_access_key_id      => 'fake_access_key_id',
      :aws_secret_access_key  => 'fake_secret_access_key',
      :provider               => 'AWS'
    }))

    @connection = Hippodamus.connection
    @directory = @connection.directories.create(
      key: "open-addresses",
      public: true
    )

    @directory.files.create(
      key: 'addresses.csv.zip',
      body: "",
      public: true
    )

    @directory.files.create(
      key: 'addresses.json.zip',
      body: "",
      public: true
    )

    Hippodamus.mongo_export("WS", "csv", "csv")

    Hippodamus.zip_by_letter("csv")
    Hippodamus.zip_all("csv")
  end

  config.after(:example, :fog) do
    Fog::Mock.reset
    Fog.unmock!
  end

end

def get_file(filename)
  File.join( "/", "tmp", "addresses", filename )
end
