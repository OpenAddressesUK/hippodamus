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
    postcode_areas.each do |area|
      puts "Exporting #{area}"
      export(area)
    end
    [
      ["csv", true],
      ["csv", false],
      ["json", true],
      ["json", false]
    ]
    .each do |array|
      type = array[0]
      with_provenance = array[1]
      single_file(type, with_provenance)
      seperated_file(type, with_provenance)
    end
    `rm -r /tmp/addresses/`
  end

  def self.single_file(type, with_provenance)
    combine(type, with_provenance)
    zip_single_file(type, with_provenance)
    file = upload(type, with_provenance)
  end

  def self.seperated_file(type, with_provenance)
    zip_by_letter(type, with_provenance)
    zip_all(type, with_provenance)
    file = upload(type, with_provenance, "split")
  end

  def self.combine(type , with_provenance)
    path = output_path(with_provenance)
    if type == "csv"
      headers = csv_header(with_provenance)
      `echo "#{headers.to_csv.strip}" > #{path}addresses.csv`
      `cat \`find #{path} | grep "[A-Z][A-Z].csv"\` | grep -v "url,pao,sao" >> #{path}addresses.csv`
    else
      `cat \`find #{path} | grep "[A-Z][A-Z].json"\` | #{ENV['JQ']} -s add > #{path}addresses.json`
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

  def self.export(area)
    addresses = Address.where("postcode.area" => area)

    csv_plain = CSV.open("#{output_path(false)}#{area}.csv", "wb")
    csv_prov = CSV.open("#{output_path(true)}#{area}.csv", "wb")
    json_plain = File.open("#{output_path(false)}#{area || "addresses"}.json","w")
    json_prov = File.open("#{output_path(true)}#{area || "addresses"}.json","w")

    csv_plain << csv_header(false)
    csv_prov << csv_header(true)
    json_plain << '['
    json_prov << '['

    first = true
    addresses.each do |address|
      # write join char
      unless first
        json_plain << ","
        json_prov << ","
      else
        first = false
      end
      # Write JSON
      json_plain << build_json(address, false)
      json_prov << build_json(address, true)
      # Write CSV
      address.provenance["activity"]["derived_from"].each do |derivation|
        csv_prov << csv_row(address, derivation, true)
      end
      csv_plain << csv_row(address, nil, false)
    end

  ensure
    csv_plain.close
    csv_prov.close

    json_plain << ']'
    json_prov << ']'

    json_plain.close
    json_prov.close
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

  def self.build_json(address, with_provenance)
    Jbuilder.encode do |json|
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

  def self.zip_by_letter(format, with_provenance)
    path = output_path(with_provenance)
    ("A".."Z").each do |letter|
      files = Dir.glob("#{path}#{letter}*#{format}")
      if files.count > 0
        Zip::File.open("#{path}#{letter}.#{format}.zip", Zip::File::CREATE) do |zipfile|
          files.each do |file|
            zipfile.add(File.basename(file), file)
          end
        end
      end
    end
  end

  def self.zip_single_file(format, with_provenance)
    path = output_path(with_provenance)
    Zip::File.open("#{path}addresses.#{format}.zip", Zip::File::CREATE) do |zipfile|
      zipfile.add(File.basename("addresses.#{format}"), "#{path}addresses.#{format}")
    end
  end

  def self.zip_all(format, with_provenance)
    path = output_path(with_provenance)
    Zip::File.open("#{path}addresses.#{format}.zip", Zip::File::CREATE) do |zipfile|
      Dir.glob("#{path}*#{format}.zip").each do |file|
        zipfile.add(File.basename(file), file)
      end
    end
  end

  def self.upload(format, with_provenance, type = nil)
    filename = filename(format, type, with_provenance)
    file = directory.files.create(
      key: "open_addresses_database/#{filename}"
    )

    # Update main file
    path = output_path(with_provenance)
    file.body = File.open("#{path}addresses.#{format}.zip").read
    file.public = true
    file.save
    file
  end

  def self.filename(format, type, with_provenance)
    type = "-#{type}" unless type.nil?
    provenance = with_provenance === false ? "addresses-only" : "full"
    filename = "#{DateTime.now.strftime("%Y-%m-%d")}-openaddressesuk-#{provenance}#{type}.#{format}.zip"
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

  def self.output_path(with_provenance)
    path = "/tmp/addresses/#{with_provenance}/"
    FileUtils.mkdir_p(path) unless File.exist?(path)
    path
  end

end
