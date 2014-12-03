Hippodamus
==========

This repository is about Open Addresses' publishing scripts that create the downloadable versions of Open Addresses' database. It is named "hippodamus", after Hippodamus of Miletus: an [ancient Greek architect, urban planner, physician, mathematician, meteorologist and philosopher commonly is considered to be the "father" of urban planning](https://en.wikipedia.org/wiki/Hippodamus_of_Miletus). Hippodamus is part of the solution Open Addresses deployed for the Alpha stage of our services. Read about Hippodamus [here](http://openaddressesuk.org/docs) or learn about Open Addresses in general [here](http://openaddressesuk.org).

Hippodamus is a Ruby script that exports the MongoDB database from [Theodolite](https://github.com/OpenAddressesUK/theodolite), uploads it to Amazon S3 and creates a `.torrent` file for seeding the data from S3.

# Setup

Clone the repo:

`git clone git@github.com:OpenAddressesUK/hippodamus.git`

Bundle:

`bundle install`

Add a file named `.env` with the following:

```
WIKIPEDIA_URL: https://en.wikipedia.org/wiki/List_of_postcode_areas_in_the_United_Kingdom
MONGO_DB: {The database name of your theodolite database}
MONGO_HOST: {Your theodolite database host}
MONGO_USERNAME: {Your theodolite database password (if applicable)}
MONGO_PASSWORD: {Your theodolite database password (if applicable)}
AWS_ACCESS_KEY: {Your Amazon Webservices access key}
AWS_SECRET_ACCESS_KEY: {Your Amazon Webservice secret access key}
```

Run the following command:

`rake upload`

##Licence
This code is open source under the MIT license. See the [LICENSE.md](LICENSE.md) file for full details.
