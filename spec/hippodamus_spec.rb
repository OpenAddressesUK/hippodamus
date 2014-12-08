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

    context "with provenance" do

      it "exports addresses for a given area" do
        55.times do |i|
          FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "AB1 123"))
        end

        Hippodamus.create_csv("AB", true)
        csv = CSV.parse(File.open(get_file("AB.csv")).read)

        expect(File.exist?(get_file("AB.csv"))).to eq(true)
        expect(csv.count).to eq((55 * 4) + 1) # We expect 4 rows per record, plus the header
      end

      it "exports the right stuff" do
        address = FactoryGirl.create(:address_with_provenance, postcode: FactoryGirl.create(:postcode, name: "AB1 123"))
        derivation = address.provenance['activity']['derived_from'].first

        Hippodamus.create_csv("AB", true)
        csv = CSV.parse(File.open(get_file("AB.csv")).read)

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

    end

    context "without provenance" do

      it "exports addresses for a given area" do
        55.times do |i|
          FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "AB1 123"))
        end

        Hippodamus.create_csv("AB", false)
        csv = CSV.parse(File.open(get_file("AB.csv")).read)

        expect(File.exist?(get_file("AB.csv"))).to eq(true)
        expect(csv.count).to eq(56)
      end

      it "exports the right stuff" do
        address = FactoryGirl.create(:address_with_provenance, postcode: FactoryGirl.create(:postcode, name: "AB1 123"))

        Hippodamus.create_csv("AB", false)
        csv = CSV.parse(File.open(get_file("AB.csv")).read)

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
            "http://alpha.openaddressesuk.org/postcodes/#{address.postcode.try(:token)}"
          ])
      end

    end

    it "zips all exant files by letter" do
      FactoryGirl.create(:address_with_provenance, postcode: FactoryGirl.create(:postcode, name: "WS1 123"))
      FactoryGirl.create(:address_with_provenance, postcode: FactoryGirl.create(:postcode, name: "WV1 123"))

      Hippodamus.create_csv("WS", false)
      Hippodamus.create_csv("WV", false)
      Hippodamus.zip_by_letter(@format)

      expect(File.exist?(get_file("W.csv.zip"))).to eq(true)
    end

    it "zips all the zips by format" do
      Hippodamus.create_csv("WS", false)
      Hippodamus.create_csv("WV", false)
      Hippodamus.create_csv("TF", false)
      Hippodamus.create_csv("ST", false)

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

    context "with provenance" do

      it "exports the right stuff" do
        address = FactoryGirl.create(:address_with_provenance, postcode: FactoryGirl.create(:postcode, name: "AB1 123"))

        Hippodamus.create_json("AB", true)
        json = JSON.parse(File.open(get_file("AB.json")).read)

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

    end

    context "without provenance" do

      it "exports the right stuff" do
        address = FactoryGirl.create(:address_with_provenance, postcode: FactoryGirl.create(:postcode, name: "AB1 123"))

        Hippodamus.create_json("AB", false)
        json = JSON.parse(File.open(get_file("AB.json")).read)

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
            }
          }
        })
      end

    end

    it "exports addresses for a given area" do
      55.times do |i|
        FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "AB1 123"))
      end

      Hippodamus.create_json("AB", false)
      json = JSON.parse(File.open(get_file("AB.json")).read)

      expect(File.exist?(get_file("AB.json"))).to eq(true)
      expect(json.count).to eq(55)
    end

    it "zips all exant files by letter" do
      Hippodamus.create_json("WS", false)
      Hippodamus.create_json("WV", false)
      Hippodamus.zip_by_letter(@format)

      expect(File.exist?(get_file("W.json.zip"))).to eq(true)
    end

    it "zips all the zips by format" do
      Hippodamus.create_json("WS", false)
      Hippodamus.create_json("WV", false)
      Hippodamus.create_json("TF", false)
      Hippodamus.create_json("ST", false)

      Hippodamus.zip_by_letter(@format)
      Hippodamus.zip_all(@format)

      expect(File.exist?(get_file("addresses.json.zip"))).to eq(true)
    end

  end

  context "upload" do

    before(:each) do
      @date = "2014-01-01"
      @filename = "#{@date}-openaddressesuk-addresses.csv.zip"
    end

    it "uploads to S3", :fog do
      Timecop.freeze(DateTime.parse(@date))

      Hippodamus.upload("csv")
      file = @directory.files.get(@filename)

      expect(file.body).to eq(File.open("/tmp/addresses/addresses.csv.zip").read)

      Timecop.return
    end

    it "uploads the torrent file", :fog, :vcr do
      Timecop.freeze(DateTime.parse(@date))

      file = Hippodamus.upload("csv")
      Hippodamus.upload_torrent(file)

      torrent = @directory.files.get("#{file.key}.torrent")

      expect(torrent.body).to match(/d8:announce55:/)

      Timecop.return
    end

  end

end
