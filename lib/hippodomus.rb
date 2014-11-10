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

# Connect to AWS
connection = Fog::Storage.new({
  :provider                 => 'AWS',
  :aws_access_key_id        => ENV['AWS_ACCESS_KEY'],
  :aws_secret_access_key    => ENV['AWS_SECRET_ACCESS_KEY']
})

# Export addresses by postcode area

{
  csv: "csv",
  json: "jsonArray"
}.each do |format, option|

  areas.each do |area|
    command = "mongoexport --host #{ENV['MONGO_HOST']} --db #{ENV['MONGO_DB']} --collection addresses --#{option} --fields pao,sao,street,locality,town,postcode --out addresses/#{area}.#{format} --sort \"{postcode: 1}\" --query \"{ postcode: /^#{area}.*/i }\""
    command << " --username #{ENV['MONGO_USERNAME']} " if ENV['MONGO_USERNAME']
    command << " --password #{ENV['MONGO_PASSWORD']} " if ENV['MONGO_PASSWORD']
    `#{command}`
  end

  # Zip CSVs by letter
  ("A".."Z").each do |letter|
    files = Dir.glob("./addresses/#{letter}*#{format}")
    if files.count > 0
      Zip::File.open("./addresses/#{letter}.#{format}.zip", Zip::File::CREATE) do |zipfile|
        files.each do |file|
          zipfile.add(File.basename(file), file)
        end
      end
    end
  end

  # Zip all the zips
  Zip::File.open("./addresses/addresses.#{format}.zip", Zip::File::CREATE) do |zipfile|
    Dir.glob("./addresses/*#{format}.zip").each do |file|
      zipfile.add(File.basename(file), file)
    end
  end

  directory = connection.directories.get("open-addresses")
  file = directory.files.get("addresses.#{format}.zip")

  # Backup old file
  directory.files.create(
    :key    => "addresses-#{DateTime.now.to_s}.#{format}.zip",
    :body   => file.body,
    :public => true
  )

  # Update main file
  file.body = File.open("./addresses/addresses.#{format}.zip")
  file.public = true
  file.save

  # Download torrent file
  open("addresses.#{format}.torrent", 'wb') do |f|
    f << open("#{file.public_url}?torrent").read
  end

end

# Cleanup
`rm -r addresses/`
