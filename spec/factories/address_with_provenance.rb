FactoryGirl.define do

  factory :address_with_provenance, parent: :address do
    provenance "activity" => {
      "executed_at" => DateTime.parse("2014-12-02T21:37:47+00:00"),
      "processing_scripts" => "https://github.com/OpenAddressesUK/distiller",
      "derived_from"=>[
        {
          "type" => "Source",
          "urls" => [
            "http://ernest.openaddressesuk.org/addresses/2934977"
          ],
          "downloaded_at" => DateTime.parse("2014-12-02T21:37:47+00:00"),
          "processing_script" => "https://github.com/OpenAddressesUK/distiller/tree/6f3cde0f903300690dc7fcc68f2967a5ddd2b581/lib/distil.rb"
        },
        {
          "type" => "Source",
          "urls" => [
            "http://alpha.openaddressesuk.org/postcodes/yq8cAU"
          ],
          "downloaded_at" => DateTime.parse("2014-12-02T21:37:47+00:00"),
          "processing_script" => "https://github.com/OpenAddressesUK/distiller/tree/6f3cde0f903300690dc7fcc68f2967a5ddd2b581/lib/distil.rb"},
        {
          "type"=>"Source",
          "urls"=>[
            "http://alpha.openaddressesuk.org/streets/1G7dpi"
          ],
          "downloaded_at"=> DateTime.parse("2014-12-02T21:37:47+00:00"),
          "processing_script"=> "https://github.com/OpenAddressesUK/distiller/tree/6f3cde0f903300690dc7fcc68f2967a5ddd2b581/lib/distil.rb"
        },
        {
          "type"=>"Source",
          "urls"=>[
            "http://alpha.openaddressesuk.org/towns/4194LO"
          ],
          "downloaded_at"=> DateTime.parse("2014-12-02T21:37:47+00:00"),
          "processing_script"=>"https://github.com/OpenAddressesUK/distiller/tree/6f3cde0f903300690dc7fcc68f2967a5ddd2b581/lib/distil.rb"
        }
      ]
    }
  end

end
