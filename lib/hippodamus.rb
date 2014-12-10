require 'nokogiri'
require 'open-uri'
require 'dotenv'
require 'zip'
require 'fog'
require 'jbuilder'
require 'csv'
require 'mongoid_address_models/require_all'

Dotenv.load
Mongoid.load!(File.join(File.dirname(__FILE__), "..", "config", "mongoid.yml"), ENV["MONGOID_ENVIRONMENT"] || :development)
Fog.credentials = { path_style: true }

class Hippodamus
  def self.perform
    [
      ["csv", true],
      ["csv", false],
      ["json", true],
      ["json", false]
    ].each do |array|
      type = array[0]
      with_provenance = array[1]
      postcode_areas.each do |area|
        puts "Exporting #{area}"
        export(type, area, with_provenance)
      end

      zip_by_letter(type)
      zip_all(type)
      file = upload(type, with_provenance)
      upload_torrent(file)
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

  def self.export(type, area, with_provenance)
    if type == "csv"
      create_csv(area, with_provenance)
    else
      create_json(area, with_provenance)
    end
  end

  def self.create_csv(area, with_provenance)
    addresses = Address.where("postcode.name" => /^#{area}[0-9]{1,2}[A-Z]?.*/i)
    Dir.mkdir("/tmp/addresses") unless File.exist?("/tmp/addresses")
    CSV.open("/tmp/addresses/#{area}.csv", "wb") do |csv|
      csv << csv_header(with_provenance)
      addresses.each do |address|
        if with_provenance === true
          address.provenance["activity"]["derived_from"].each do |derivation|
            csv << csv_row(address, derivation, true)
          end
        else
          csv << csv_row(address, nil, false)
        end
      end
    end
  end

  def self.csv_row(address, derivation, with_provenance)
    row = [
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
      url_for(address.postcode)
    ]
    row.push(address.provenance['activity']['executed_at'],
      address.provenance['activity']['processing_scripts'],
      derivation['urls'].first,
      derivation['downloaded_at'],
      derivation['processing_script']) if with_provenance === true
    row
  end

  def self.csv_header(with_provenance)
    header = [
      "url","pao","sao","street.name","street.url","locality.name",
      "locality.url","town.name","town.url","postcode.name",
      "postcode.url"
    ]
    header.push("provenance.activity.executed_at",
      "provenance.processing_script","provenance.derived_from.url",
      "provenance.derived_from.downloaded_at",
      "provenance.derived_from.processing_script") if with_provenance === true
    header
  end

  def self.create_json(area, with_provenance)
    return nil if File.exist?("/tmp/addresses/#{area}.json")
    Dir.mkdir("/tmp/addresses") unless File.exist?("/tmp/addresses")
    addresses = Address.where("postcode.name" => /^#{area}[0-9]{1,2}[A-Z]?.*/i)
    json = build_json(addresses, with_provenance)
    File.open("/tmp/addresses/#{area}.json","w") do |f|
      f.write(json)
    end
  end

  def self.build_json(addresses, with_provenance)
    Jbuilder.encode do |json|
      json.array! addresses do |address|
        json.address do
          json.url url_for(address)
          json.sao address.sao
          json.pao address.pao
          json.street address_part(json, address, "street")
          json.locality address_part(json, address, "locality")
          json.town address_part(json, address, "town")
          json.postcode address_part(json, address, "postcode")
          json.provenance address.provenance if with_provenance === true
        end
      end
    end
  end

  def self.address_part(json, address, part)
    json.set! part do
      address_part_name(json, address, part)
      json.url url_for(address.send(part))
    end
  end

  def self.address_part_name(json, address, part)
    if part == "postcode"
      json.name (address.send(part).try(:name))
    else
      json.name do
        json.en [
          address.send(part).try(:name)
        ]
        json.cy []
      end
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

  def self.upload(format, with_provenance)
    filename = filename(format, with_provenance)
    file = directory.files.create(
      key: "open_addresses_database/#{filename}"
    )

    # Update main file
    file.body = File.open("/tmp/addresses/addresses.#{format}.zip").read
    file.public = true
    file.save
    file
  end

  def self.filename(format, with_provenance)
    type = with_provenance === false ? "addresses-only" : "full"
    filename = "#{DateTime.now.strftime("%Y-%m-%d")}-openaddressesuk-#{type}.#{format}.zip"
  end

  def self.upload_torrent(file)
    torrent = directory.files.get("#{file.key}.torrent")
    torrent_body = open("#{file.public_url}?torrent").read

    file = directory.files.create(key: "#{file.key}.torrent") if torrent.nil?
    file.body = torrent_body
    file.public = true
    file.save
  end

  def self.directory
    @@directory = connection.directories.get(ENV['AWS_BUCKET'])
  end

  def self.connection
    @@connection = Fog::Storage.new({
      :provider                 => 'AWS',
      :aws_access_key_id        => ENV['AWS_ACCESS_KEY'],
      :aws_secret_access_key    => ENV['AWS_SECRET_ACCESS_KEY'],
      :region                   => 'eu-west-1'
    })
  end

  def self.url_for(obj)
    unless obj.nil?
      "http://alpha.openaddressesuk.org/#{obj.class.name.downcase.pluralize}/#{obj.token}"
    end
  end
end
