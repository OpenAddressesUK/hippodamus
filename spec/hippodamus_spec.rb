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

      it "exports addresses for all areas" do
        10.times do |i|
          FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "AB1 123"))
          FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "CD1 123"))
          FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "EF1 123"))
          FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "GH1 123"))
        end

        Hippodamus.create_csv(nil, true)
        csv = CSV.parse(File.open(get_file("addresses.csv")).read)

        expect(File.exist?(get_file("addresses.csv"))).to eq(true)
        expect(csv.count).to eq((40 * 4) + 1) # We expect 4 rows per record, plus the header
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

      it "creates the correct filename" do
        Timecop.freeze(DateTime.parse("2014-01-01"))

        filename = Hippodamus.filename("csv", "single", true)
        expect(filename).to eq("2014-01-01-openaddressesuk-single-full.csv.zip")

        Timecop.return
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

      it "exports addresses for all areas" do
        10.times do |i|
          FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "AB1 123"))
          FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "CD1 123"))
          FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "EF1 123"))
          FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "GH1 123"))
        end

        Hippodamus.create_csv(nil, false)
        csv = CSV.parse(File.open(get_file("addresses.csv")).read)

        expect(File.exist?(get_file("addresses.csv"))).to eq(true)
        expect(csv.count).to eq(41) # We expect 4 rows per record, plus the header
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

      it "creates the correct filename" do
        Timecop.freeze(DateTime.parse("2014-01-01"))

        filename = Hippodamus.filename("csv", "single", false)
        expect(filename).to eq("2014-01-01-openaddressesuk-single-addresses-only.csv.zip")

        Timecop.return
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

    it "zips a single file" do
      Hippodamus.create_csv(nil, false)
      Hippodamus.zip_single_file(@format)

      expect(File.exist?(get_file("addresses.csv.zip"))).to eq(true)
      Zip::File.open(get_file("addresses.csv.zip")) do |zip|
        entry = zip.glob('*.csv')
        expect(entry.count).to eq(1)
        expect(entry.first.name).to eq("addresses.csv")
      end
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
              "name" => address.postcode.name,
              "url" => "http://alpha.openaddressesuk.org/postcodes/#{address.postcode.token}"
            },
            "provenance" => JSON.parse(address.provenance.to_json)
          }
        })
      end

      it "creates the correct filename" do
        Timecop.freeze(DateTime.parse("2014-01-01"))

        filename = Hippodamus.filename("json", "single", true)
        expect(filename).to eq("2014-01-01-openaddressesuk-single-full.json.zip")

        Timecop.return
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
              "name" => address.postcode.name,
              "url" => "http://alpha.openaddressesuk.org/postcodes/#{address.postcode.token}"
            }
          }
        })
      end

      it "exports the right stuff when there is no locality" do
        address = FactoryGirl.create(:address_with_provenance, locality: nil, postcode: FactoryGirl.create(:postcode, name: "AB1 123"))

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
                "en"=>[nil],
                "cy"=>[]
              },
              "url" => nil
            },
            "town" => {
              "name" => {
                "en"=>[address.town.name],
                "cy"=>[]
              },
              "url" => "http://alpha.openaddressesuk.org/towns/#{address.town.token}"
            },
            "postcode" => {
              "name" => address.postcode.name,
              "url" => "http://alpha.openaddressesuk.org/postcodes/#{address.postcode.token}"
            }
          }
        })
      end

      it "creates the correct filename" do
        Timecop.freeze(DateTime.parse("2014-01-01"))

        filename = Hippodamus.filename("json", "single", false)
        expect(filename).to eq("2014-01-01-openaddressesuk-single-addresses-only.json.zip")

        Timecop.return
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

    it "exports addresses for all areas" do
      10.times do |i|
        FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "AB1 123"))
        FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "CD1 123"))
        FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "EF1 123"))
        FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "GH1 123"))
      end

      Hippodamus.create_json(nil, true)
      json = JSON.parse(File.open(get_file("addresses.json")).read)

      expect(File.exist?(get_file("addresses.json"))).to eq(true)
      expect(json.count).to eq(40)
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

    it "zips a single file" do
      Hippodamus.create_json(nil, false)
      Hippodamus.zip_single_file(@format)

      expect(File.exist?(get_file("addresses.json.zip"))).to eq(true)
      Zip::File.open(get_file("addresses.json.zip")) do |zip|
        entry = zip.glob('*.json')
        expect(entry.count).to eq(1)
        expect(entry.first.name).to eq("addresses.json")
      end
    end

  end

  context "upload" do

    before(:each) do
      @date = "2014-01-01"
    end

    it "uploads to S3", :fog do
      Timecop.freeze(DateTime.parse(@date))

      file = Hippodamus.upload("csv", "split", true)
      md5 = Digest::MD5.hexdigest(file.body)

      expect(md5).to eq(Digest::MD5.file('/tmp/addresses/addresses.csv.zip').hexdigest)

      Timecop.return
    end

    it "uploads the torrent file", :fog do
      Timecop.freeze(DateTime.parse(@date))

      stub_request(:get, "https://s3-eu-west-1.amazonaws.com/#{ENV['AWS_BUCKET']}/open_addresses_database/#{@date}-openaddressesuk-split-full.csv.zip?torrent").
              to_return(body: "TORRENT PLACEHOLDER")

      file = Hippodamus.upload("csv", "split", true)
      Hippodamus.upload_torrent(file)

      torrent = @directory.files.get("#{file.key}.torrent")

      expect(torrent.body).to match(/TORRENT PLACEHOLDER/)

      Timecop.return
    end

  end

end
