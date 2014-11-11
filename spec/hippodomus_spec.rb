require 'spec_helper'

describe Hippodomus do

  it "gets a list of postcode areas", :vcr do
    postcode_areas = Hippodomus.postcode_areas
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
      Hippodomus.mongo_export("AB", @option, @format)
      csv = CSV.parse(File.open(get_file("AB.csv")).read)

      expect(File.exist?(get_file("AB.csv"))).to eq(true)
      expect(csv.count).to eq(55)
    end

    it "zips all exant files by letter" do
      Hippodomus.mongo_export("WS", @option, @format)
      Hippodomus.mongo_export("WV", @option, @format)
      Hippodomus.zip_by_letter(@format)

      expect(File.exist?(get_file("W.csv.zip"))).to eq(true)
    end

    it "zips all the zips by format" do
      Hippodomus.mongo_export("WS", @option, @format)
      Hippodomus.mongo_export("WV", @option, @format)
      Hippodomus.mongo_export("TF", @option, @format)
      Hippodomus.mongo_export("ST", @option, @format)

      Hippodomus.zip_by_letter(@format)
      Hippodomus.zip_all(@format)

      expect(File.exist?(get_file("addresses.csv.zip"))).to eq(true)
    end

  end

  context "when format is JSON" do

    before(:each) do
      @format = "json"
      @option = "jsonArray"
    end

    it "exports addresses for a given area" do
      Hippodomus.mongo_export("AB", @option, @format)
      json = JSON.parse(File.open(get_file("AB.json")).read)

      expect(File.exist?(get_file("AB.json"))).to eq(true)
      expect(json.count).to eq(54)
    end

    it "zips all exant files by letter" do
      Hippodomus.mongo_export("WS", @option, @format)
      Hippodomus.mongo_export("WV", @option, @format)
      Hippodomus.zip_by_letter(@format)

      expect(File.exist?(get_file("W.json.zip"))).to eq(true)
    end

    it "zips all the zips by format" do
      Hippodomus.mongo_export("WS", @option, @format)
      Hippodomus.mongo_export("WV", @option, @format)
      Hippodomus.mongo_export("TF", @option, @format)
      Hippodomus.mongo_export("ST", @option, @format)

      Hippodomus.zip_by_letter(@format)
      Hippodomus.zip_all(@format)

      expect(File.exist?(get_file("addresses.json.zip"))).to eq(true)
    end

  end

  it "uploads to S3", :fog do
    Hippodomus.upload("csv")
    file = @directory.files.get("addresses.csv.zip")

    expect(file.body).to eq(File.open("/tmp/addresses/addresses.csv.zip").read)
  end

  it "backs up the old version", :fog do
    Timecop.freeze

    Hippodomus.upload("csv")
    old_file = @directory.files.get("addresses.csv.zip")

    `rm -r /tmp/addresses/ > /dev/null 2>&1`

    Hippodomus.mongo_export("AB", "csv", "csv")
    Hippodomus.zip_by_letter("csv")
    Hippodomus.zip_all("csv")

    new_file = Hippodomus.upload("csv")
    backup = @directory.files.get("addresses-#{DateTime.now.to_s}.csv.zip")

    expect(backup.body).to eq(old_file.body)

    Timecop.return
  end

  it "downloads the torrent", :fog, :vcr do
    file = Hippodomus.upload("csv")
    Hippodomus.get_torrent(file, "csv")

    expect(File.exist?("addresses.csv.torrent")).to eq(true)
  end

end
