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

      before(:each) do
        @with_provenance = true
      end

      it "exports addresses for a given area" do
        55.times do |i|
          FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "AB1 123", area: "AB"))
        end

        Hippodamus.export("AB")
        csv = CSV.parse(File.open(get_file("AB.csv", @with_provenance)).read)

        expect(File.exist?(get_file("AB.csv", @with_provenance))).to eq(true)
        expect(csv.count).to eq((55 * 4) + 1) # We expect 4 rows per record, plus the header
      end

      it "exports the right stuff" do
        address = FactoryGirl.create(:address_with_provenance, postcode: FactoryGirl.create(:postcode, name: "AB1 123", area: "AB"))
        derivation = address.provenance['activity']['derived_from'].first

        Hippodamus.export("AB")
        csv = CSV.parse(File.open(get_file("AB.csv", @with_provenance)).read)

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

      it "combines multiple files into one" do
        10.times do |i|
          FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "AB1 123", area: "AB"))
          FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "CD1 123", area: "CD"))
          FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "EF1 123", area: "EF"))
          FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "GH1 123", area: "GH"))
        end

        Hippodamus.export("AB")
        Hippodamus.export("CD")
        Hippodamus.export("EF")
        Hippodamus.export("GH")

        Hippodamus.combine("csv", @with_provenance)

        csv = CSV.parse(File.open(get_file("addresses.csv", @with_provenance)).read)

        expect(csv.count).to eq((40 * 4) + 1) # We expect 4 rows per record, plus the header
      end

    end

    context "without provenance" do

      before(:each) do
        @with_provenance = false
      end

      it "exports addresses for a given area" do
        55.times do |i|
          FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "AB1 123", area: "AB"))
          FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "CD1 123", area: "CD"))
        end

        Hippodamus.export("AB")
        csv = CSV.parse(File.open(get_file("AB.csv", @with_provenance)).read)

        expect(File.exist?(get_file("AB.csv", @with_provenance))).to eq(true)
        expect(csv.count).to eq(56)
      end

      it "exports the right stuff" do
        address = FactoryGirl.create(:address_with_provenance, postcode: FactoryGirl.create(:postcode, name: "AB1 123", area: "AB"))

        Hippodamus.export("AB")
        csv = CSV.parse(File.open(get_file("AB.csv", @with_provenance)).read)

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

      it "combines multiple files into one" do
        10.times do |i|
          FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "AB1 123", area: "AB"))
          FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "CD1 123", area: "CD"))
          FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "EF1 123", area: "EF"))
          FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "GH1 123", area: "GH"))
        end

        Hippodamus.export("AB")
        Hippodamus.export("CD")
        Hippodamus.export("EF")
        Hippodamus.export("GH")

        Hippodamus.combine("csv", @with_provenance)

        csv = CSV.parse(File.open(get_file("addresses.csv", @with_provenance)).read)

        expect(csv.count).to eq(41) # We expect 1 row per record, plus the header
      end

    end

    it "zips all exant files by letter" do
      FactoryGirl.create(:address_with_provenance, postcode: FactoryGirl.create(:postcode, name: "WS1 123", area: "WS"))
      FactoryGirl.create(:address_with_provenance, postcode: FactoryGirl.create(:postcode, name: "WV1 123", area: "WV"))

      Hippodamus.export("WS")
      Hippodamus.export("WV")
      Hippodamus.zip_by_letter(@format, false)

      expect(File.exist?(get_file("W.csv.zip", false))).to eq(true)
    end

    it "zips all the zips by format" do
      Hippodamus.export("WS")
      Hippodamus.export("WV")
      Hippodamus.export("TF")
      Hippodamus.export("ST")

      Hippodamus.zip_by_letter(@format, false)
      Hippodamus.zip_all(@format, false)

      expect(File.exist?(get_file("addresses.csv.zip", false))).to eq(true)
    end

  end

  context "when format is JSON" do

    before(:each) do
      @format = "json"
      @option = "jsonArray"
    end

    context "with provenance" do

      before(:each) do
        @with_provenance = true
      end

      it "exports the right stuff" do
        address = FactoryGirl.create(:address_with_provenance, postcode: FactoryGirl.create(:postcode, name: "AB1 123", area: "AB"))

        Hippodamus.export("AB")
        json = JSON.parse(File.open(get_file("AB.json", @with_provenance)).read)

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

    end

    context "without provenance" do

      before(:each) do
        @with_provenance = false
      end

      it "exports the right stuff" do
        address = FactoryGirl.create(:address_with_provenance, postcode: FactoryGirl.create(:postcode, name: "AB1 123", area: "AB"))

        Hippodamus.export("AB")
        json = JSON.parse(File.open(get_file("AB.json", @with_provenance)).read)

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
        address = FactoryGirl.create(:address_with_provenance, locality: nil, postcode: FactoryGirl.create(:postcode, name: "AB1 123", area: "AB"))

        Hippodamus.export("AB")
        json = JSON.parse(File.open(get_file("AB.json", @with_provenance)).read)

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

      it "exports addresses for a given area" do
        55.times do |i|
          FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "AB1 123", area: "AB"))
          FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "CD1 123", area: "CD"))
        end

        Hippodamus.export("AB")
        json = JSON.parse(File.open(get_file("AB.json", @with_provenance)).read)

        expect(File.exist?(get_file("AB.json", @with_provenance))).to eq(true)
        expect(json.count).to eq(55)
      end

      it "combines multiple files into one" do
        10.times do |i|
          FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "AB1 123", area: "AB"))
          FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "CD1 123", area: "CD"))
          FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "EF1 123", area: "EF"))
          FactoryGirl.create(:address_with_provenance, pao: i, postcode: FactoryGirl.create(:postcode, name: "GH1 123", area: "GH"))
        end

        Hippodamus.export("AB")
        Hippodamus.export("CD")
        Hippodamus.export("EF")
        Hippodamus.export("GH")

        Hippodamus.combine("json", @with_provenance)

        json = JSON.parse(File.open(get_file("addresses.json", @with_provenance)).read)

        expect(File.exist?(get_file("addresses.json", @with_provenance))).to eq(true)
        expect(json.count).to eq(40)
      end

      it "zips all exant files by letter" do
        Hippodamus.export("WS")
        Hippodamus.export("WV")
        Hippodamus.zip_by_letter(@format, @with_provenance)

        expect(File.exist?(get_file("W.json.zip", @with_provenance))).to eq(true)
      end

      it "zips all the zips by format" do
        Hippodamus.export("WS")
        Hippodamus.export("WV")
        Hippodamus.export("TF")
        Hippodamus.export("ST")

        Hippodamus.zip_by_letter(@format, @with_provenance)
        Hippodamus.zip_all(@format, @with_provenance)

        expect(File.exist?(get_file("addresses.json.zip", @with_provenance))).to eq(true)
      end

    end

  end

  context "upload" do

    before(:each) do
      @date = "2014-01-01"
    end

    it "uploads to S3", :fog do
      Timecop.freeze(DateTime.parse(@date))

      file = Hippodamus.upload("csv", false, "split")
      md5 = Digest::MD5.hexdigest(file.body)

      expect(md5).to eq(Digest::MD5.file('/tmp/addresses/false/addresses.csv.zip').hexdigest)

      Timecop.return
    end
  end

  context "creating filenames" do
    [
      {
        format: "csv",
        split: nil,
        provenance: false,
        name: "Addresses only as a single CSV file",
        result: "2014-01-01-openaddressesuk-addresses-only.csv.zip"
      },
      {
        format: "json",
        split: nil,
        provenance: false,
        name: "Addresses only as a single JSON file",
        result: "2014-01-01-openaddressesuk-addresses-only.json.zip"
      },
      {
        format: "csv",
        split: "split",
        provenance: false,
        name: "Addresses only as a split CSV file",
        result: "2014-01-01-openaddressesuk-addresses-only-split.csv.zip"
      },
      {
        format: "json",
        split: "split",
        provenance: false,
        name: "Addresses only as a split JSON file",
        result: "2014-01-01-openaddressesuk-addresses-only-split.json.zip"
      },
      {
        format: "csv",
        split: nil,
        provenance: true,
        name: "Full export as a single CSV file",
        result: "2014-01-01-openaddressesuk-full.csv.zip"
      },
      {
        format: "json",
        split: nil,
        provenance: true,
        name: "Full export as a single JSON file",
        result: "2014-01-01-openaddressesuk-full.json.zip"
      },
      {
        format: "csv",
        split: "split",
        provenance: true,
        name: "Full export as a split CSV file",
        result: "2014-01-01-openaddressesuk-full-split.csv.zip"
      },
      {
        format: "json",
        split: "split",
        provenance: true,
        name: "Full export as a split JSON file",
        result: "2014-01-01-openaddressesuk-full-split.json.zip"
      }
    ].each do |scenario|
      it "creates the correct filename for #{scenario[:name]}" do
        Timecop.freeze(DateTime.parse("2014-01-01"))

        filename = Hippodamus.filename(scenario[:format], scenario[:split], scenario[:provenance])
        expect(filename).to eq(scenario[:result])

        Timecop.return
      end
    end
  end



end
