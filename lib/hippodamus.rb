require 'nokogiri'
require 'open-uri'
require 'dotenv'
require 'zip'
require 'fog'
require 'jbuilder'
require 'mongoid_address_models/require_all'

Dotenv.load
Mongoid.load!(File.join(File.dirname(__FILE__), "..", "config", "mongoid.yml"), ENV["MONGOID_ENVIRONMENT"] || :development)

class Hippodamus
  def self.perform
    [
      "csv",
      "json"
    ].each do |format|
      postcode_areas.each do |area|
        export(type, area)
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

  def self.export(type, area)
    if type == "csv"
      create_csv(area)
    else
      create_json(area)
    end
  end

  def self.create_csv(area)
    addresses = Address.where("postcode.name" => /^#{area}[0-9]{1,2}[A-Z]?.*/i)
    Dir.mkdir("/tmp/addresses") unless File.exist?("/tmp/addresses")
    CSV.open("/tmp/addresses/#{area}.csv", "wb") do |csv|
      csv << csv_header
      addresses.each do |address|
        address.provenance["activity"]["derived_from"].each do |derivation|
          csv << csv_row(address, derivation)
        end
      end
    end
  end

  def self.csv_row(address, derivation)
    [
      url_for(address),
      address.pao,
      address.sao,
      address.street.try(:name),
      url_for(address.street),
      address.locality.try(:name),
      url_for(address.locality),
      address.town.try(:name),
      url_for(address.town),
      address.postcode.try(:name),
      url_for(address.postcode),
      address.provenance['activity']['executed_at'],
      address.provenance['activity']['processing_scripts'],
      derivation['urls'].first,
      derivation['downloaded_at'],
      derivation['processing_script']
    ]
  end

  def self.csv_header
    [
      "url","pao","sao","street.name","street.url","locality.name",
      "locality.url","town.name","town.url","postcode.name",
      "postcode.url","provenance.activity.executed_at",
      "provenance.processing_script","provenance.derived_from.url",
      "provenance.derived_from.downloaded_at",
      "provenance.derived_from.processing_script"
    ]
  end

  def self.create_json(area)
    Dir.mkdir("/tmp/addresses") unless File.exist?("/tmp/addresses")
    addresses = Address.where("postcode.name" => /^#{area}[0-9]{1,2}[A-Z]?.*/i)
    json = build_json(addresses)
    File.open("/tmp/addresses/#{area}.json","w") do |f|
      f.write(json)
    end
  end

  def self.build_json(addresses)
    Jbuilder.encode do |json|
      json.array! addresses do |address|
        json.address do
          json.url url_for(address)
          json.sao address.sao
          json.pao address.pao
          json.street address_part(json, address.street)
          json.locality address_part(json, address.locality)
          json.town address_part(json, address.town)
          json.postcode address_part(json, address.postcode)
          json.provenance address.provenance
        end
      end
    end
  end

  def self.address_part(json, part)
    json.set! part.class.to_s.downcase do
      json.name do
        json.en [
          part.try(:name)
        ]
        json.cy []
      end
      json.url url_for(part)
    end
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

  def self.url_for(obj)
    unless obj.nil?
      "http://alpha.openaddressesuk.org/#{obj.class.name.downcase.pluralize}/#{obj.token}"
    end
  end
end
