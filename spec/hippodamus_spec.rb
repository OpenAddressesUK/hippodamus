require 'spec_helper'

describe Hippodamus do

  it "gets a list of postcode areas", :vcr do
    postcode_areas = Hippodamus.postcode_areas
    expect(postcode_areas.count).to eq(121)
    expect(postcode_areas.first).to eq("AB")
    expect(postcode_areas.last).to eq("ZE")
  end

  context "when format is CSV" do

    before(:each) do
      @format = "csv"
      @option = "csv"
    end

    it "exports addresses for a given area" do
      55.times do |i|
        FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "AB1 123"))
      end

      Hippodamus.create_csv("AB")
      csv = CSV.parse(File.open(get_file("AB.csv")).read)
      address = Address.last
      derivation = address.provenance['activity']['derived_from'].first

      expect(File.exist?(get_file("AB.csv"))).to eq(true)
      expect(csv.count).to eq((55 * 4) + 1) # We expect 4 rows per record, plus the header
      expect(csv[1]).to eq([
          "http://alpha.openaddressesuk.org/addresses/#{address.token}",
          address.pao,
          address.sao,
          address.street.try(:name),
          "http://alpha.openaddressesuk.org/streets/#{address.street.try(:token)}",
          address.locality.try(:name),
          "http://alpha.openaddressesuk.org/localities/#{address.locality.try(:token)}",
          address.town.try(:name),
          "http://alpha.openaddressesuk.org/towns/#{address.town.try(:token)}",
          address.postcode.try(:name),
          "http://alpha.openaddressesuk.org/postcodes/#{address.postcode.try(:token)}",
          address.provenance['activity']['executed_at'].to_s,
          address.provenance['activity']['processing_scripts'],
          derivation['urls'].first,
          derivation['downloaded_at'].to_s,
          derivation['processing_script']
        ])
    end

    it "zips all exant files by letter" do
      FactoryGirl.create(:address_with_provenance, postcode: FactoryGirl.create(:postcode, name: "WS1 123"))
      FactoryGirl.create(:address_with_provenance, postcode: FactoryGirl.create(:postcode, name: "WV1 123"))

      Hippodamus.create_csv("WS")
      Hippodamus.create_csv("WV")
      Hippodamus.zip_by_letter(@format)

      expect(File.exist?(get_file("W.csv.zip"))).to eq(true)
    end

    it "zips all the zips by format" do
      Hippodamus.create_csv("WS")
      Hippodamus.create_csv("WV")
      Hippodamus.create_csv("TF")
      Hippodamus.create_csv("ST")

      Hippodamus.zip_by_letter(@format)
      Hippodamus.zip_all(@format)

      expect(File.exist?(get_file("addresses.csv.zip"))).to eq(true)
    end

  end

  context "when format is JSON" do

    before(:each) do
      @format = "json"
      @option = "jsonArray"
    end

    it "exports addresses for a given area" do
      55.times do |i|
        FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "AB1 123"))
      end

      Hippodamus.create_json("AB")
      address = Address.last
      json = JSON.parse(File.open(get_file("AB.json")).read)

      expect(File.exist?(get_file("AB.json"))).to eq(true)
      expect(json.count).to eq(55)
      expect(json.first).to eq({
        "address" => {
          "url" => "http://alpha.openaddressesuk.org/addresses/#{address.token}",
          "sao" => address.sao,
          "pao" => address.pao,
          "street" => {
            "name" => {
              "en"=>[address.street.name],
              "cy"=>[]
            },
            "url" => "http://alpha.openaddressesuk.org/streets/#{address.street.token}"
          },
          "locality" => {
            "name" => {
              "en"=>[address.locality.name],
              "cy"=>[]
            },
            "url" => "http://alpha.openaddressesuk.org/localities/#{address.locality.token}"
          },
          "town" => {
            "name" => {
              "en"=>[address.town.name],
              "cy"=>[]
            },
            "url" => "http://alpha.openaddressesuk.org/towns/#{address.town.token}"
          },
          "postcode" => {
            "name" => {
              "en"=>[address.postcode.name],
              "cy"=>[]
            },
            "url" => "http://alpha.openaddressesuk.org/postcodes/#{address.postcode.token}"
          },
          "provenance" => JSON.parse(address.provenance.to_json)
        }
      })
    end

    it "zips all exant files by letter" do
      Hippodamus.create_json("WS")
      Hippodamus.create_json("WV")
      Hippodamus.zip_by_letter(@format)

      expect(File.exist?(get_file("W.json.zip"))).to eq(true)
    end

    it "zips all the zips by format" do
      Hippodamus.create_json("WS")
      Hippodamus.create_json("WV")
      Hippodamus.create_json("TF")
      Hippodamus.create_json("ST")

      Hippodamus.zip_by_letter(@format)
      Hippodamus.zip_all(@format)

      expect(File.exist?(get_file("addresses.json.zip"))).to eq(true)
    end

  end

  it "uploads to S3", :fog do
    Hippodamus.upload("csv")
    file = @directory.files.get("addresses.csv.zip")

    expect(file.body).to eq(File.open("/tmp/addresses/addresses.csv.zip").read)
  end

  it "backs up the old version", :fog do
    Timecop.freeze

    Hippodamus.upload("csv")
    old_file = @directory.files.get("addresses.csv.zip")

    `rm -r /tmp/addresses/ > /dev/null 2>&1`

    Hippodamus.create_csv("AB")
    Hippodamus.zip_by_letter("csv")
    Hippodamus.zip_all("csv")

    new_file = Hippodamus.upload("csv")
    backup = @directory.files.get("addresses-#{DateTime.now.to_s}.csv.zip")

    expect(backup.body).to eq(old_file.body)

    Timecop.return
  end

  it "uploads the torrent file", :fog, :vcr do
    file = Hippodamus.upload("csv")
    Hippodamus.upload_torrent(file, "csv")

    torrent = @directory.files.get("addresses.csv.torrent")

    expect(torrent.body).to match(/d8:announce55:/)
  end

end
