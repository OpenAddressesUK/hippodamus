require 'nokogiri'
require 'open-uri'
require 'dotenv'
require 'zip'
require 'fog'

Dotenv.load

class Hippodamus
  def self.perform
    {
      csv: "csv",
      json: "jsonArray"
    }.each do |format, option|
      postcode_areas.each do |area|
        mongo_export(area, option, format)
      end

      zip_by_letter(format)
      zip_all(format)
      file = upload(format)
      upload_torrent(file, format)
      `rm -r /tmp/addresses/`
    end
  end

  def self.postcode_areas
    # Load postcode areas from Wikipedia
    doc = Nokogiri::HTML(open(ENV['WIKIPEDIA_URL']))

    table = doc.css("table.wikitable:first-of-type")

    areas = []

    table.css("tr").each do |row|
      areas << row.css("td").first.inner_text rescue nil
    end

    areas
  end

  def self.connection
    @@connection = Fog::Storage.new({
      :provider                 => 'AWS',
      :aws_access_key_id        => ENV['AWS_ACCESS_KEY'],
      :aws_secret_access_key    => ENV['AWS_SECRET_ACCESS_KEY']
    })
  end

  def self.mongo_export(area, option, format)
    command = "mongoexport --host #{ENV['MONGO_HOST']} --db #{ENV['MONGO_DB']} --collection addresses --#{option} --fields pao,sao,street,locality,town,postcode --out /tmp/addresses/#{area}.#{format} --sort \"{postcode: 1}\" --query \"{ postcode: /^#{area}[0-9]{1,2}[A-Z]?.*/i }\""
    command << " --username #{ENV['MONGO_USERNAME']} " if ENV['MONGO_USERNAME']
    command << " --password #{ENV['MONGO_PASSWORD']} " if ENV['MONGO_PASSWORD']
    `#{command} > /dev/null 2>&1`
  end

  def self.zip_by_letter(format)
    ("A".."Z").each do |letter|
      files = Dir.glob("/tmp/addresses/#{letter}*#{format}")
      if files.count > 0
        Zip::File.open("/tmp/addresses/#{letter}.#{format}.zip", Zip::File::CREATE) do |zipfile|
          files.each do |file|
            zipfile.add(File.basename(file), file)
          end
        end
      end
    end
  end

  def self.zip_all(format)
    Zip::File.open("/tmp/addresses/addresses.#{format}.zip", Zip::File::CREATE) do |zipfile|
      Dir.glob("/tmp/addresses/*#{format}.zip").each do |file|
        zipfile.add(File.basename(file), file)
      end
    end
  end

  def self.upload(format)
    file = directory.files.get("addresses.#{format}.zip")

    if file.nil?
      file = directory.files.create(
        :key    => "addresses.#{format}.zip"
      )
    else
      # Backup old file
      directory.files.create(
        :key    => "addresses-#{DateTime.now.to_s}.#{format}.zip",
        :body   => file.body,
        :public => true
      )
    end

    # Update main file
    file.body = File.open("/tmp/addresses/addresses.#{format}.zip")
    file.public = true
    file.save
    file
  end

  def self.upload_torrent(file, format)
    torrent = directory.files.get("addresses.#{format}.torrent")
    torrent_body = open("#{file.public_url}?torrent").read

    file = directory.files.create(key: "addresses.#{format}.torrent") if torrent.nil?
    file.body = torrent_body
    file.public = true
    file.save
  end

  def self.directory
    @@directory = connection.directories.get("open-addresses")
  end
end
