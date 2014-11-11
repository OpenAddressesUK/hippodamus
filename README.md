# Hippodamus

A Ruby script that exports the MongoDB database from [Theodolite](https://github.com/OpenAddressesUK/theodolite), uploads it to Amazon S3 and creates a `.torrent` file for seeding the data from S3.

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

# Wut?

![](http://www.003022710.net/pimages/themistokles.jpg)

> Hippodamus of Miletus, was an ancient Greek architect, urban planner, physician, mathematician, meteorologist and philosopher and is considered to be the “father” of urban planning, the namesake of Hippodamian plan of city layouts.

[Wikipedia](https://en.wikipedia.org/wiki/Hippodamus_of_Miletus)
