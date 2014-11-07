require 'nokogiri'
require 'open-uri'
require 'dotenv'
require 'zip'
require 'fog'

Dotenv.load

# Load postcode areas from Wikipedia
doc = Nokogiri::HTML(open(ENV['WIKIPEDIA_URL']))

table = doc.css("table.wikitable:first-of-type")

areas = []

table.css("tr").each do |row|
  areas << row.css("td").first.inner_text rescue nil
end

# Export addresses by postcode area
areas.each do |area|
  command = "mongoexport --host #{ENV['MONGO_HOST']} --db #{ENV['MONGO_DB']} --collection addresses --csv --fields pao,sao,street,locality,town,postcode --out addresses/#{area}.csv --sort \"{postcode: 1}\" --query \"{ postcode: /^#{area}.*/i }\""
  command << " --username #{ENV['MONGO_USERNAME']} " if ENV['MONGO_USERNAME']
  command << " --password #{ENV['MONGO_PASSWORD']} " if ENV['MONGO_PASSWORD']
  `#{command}`
end

# Zip CSVs by letter
("A".."Z").each do |letter|
  files = Dir.glob("./addresses/#{letter}*")
  if files.count > 0
    Zip::File.open("./addresses/#{letter}.zip", Zip::File::CREATE) do |zipfile|
      files.each do |file|
        zipfile.add(File.basename(file), file)
      end
    end
  end
end

# Zip all the zips
Zip::File.open("./addresses/addresses.zip", Zip::File::CREATE) do |zipfile|
  Dir.glob("./addresses/*.zip").each do |file|
    zipfile.add(File.basename(file), file)
  end
end

# Connect to AWS
connection = Fog::Storage.new({
  :provider                 => 'AWS',
  :aws_access_key_id        => ENV['AWS_ACCESS_KEY'],
  :aws_secret_access_key    => ENV['AWS_SECRET_ACCESS_KEY']
})

directory = connection.directories.get("open-addresses")
file = directory.files.get("addresses.zip")

# Backup old file
directory.files.create(
  :key    => "addresses-#{DateTime.now.to_s}.zip",
  :body   => file.body,
  :public => true
)

# Update main file
file.body = File.open("./addresses/addresses.zip")
file.public = true
file.save

# Update torrent file
torrent = directory.files.get("addresses.torrent")
torrent.body = open("#{file.public_url}?torrent").read
torrent.public = true
torrent.save
