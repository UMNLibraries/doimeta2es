# DOIMeta2ES - Index DOI metadata into Elasticsearch

## Installation
```shell
$ bundle install
```

## Command line usage
The executable `bin/doimeta2es` may be used to index metadata files (XML or
JSON) on disk or to lookup a DOI's metadata and optionally index it.

```shell
# Create indexes and mappings
$ bundle exec bin/doimeta2es setup

# Just one specific index
$ bundle exec bin/doimeta2es setup --index=article

# Bulk indexing of files on disk
# Note: this gets slow with tens of thousands of files, and may
# even exceed shell expansion limits
#
# Pass filenames to index as arguments, or a glob pattern
# --batchsize default is 100
# Add --verbosity=2 to see full transactions with Elasticsearch
$ bundle exec bin/doimeta2es index --batchsize=1000 /path/to/metadata/files/*.xml

# Read all files recursively in --readdir for valid metadata file types
# and index them in batch. The best option if you have a large number of files,
# will not run afoul of command line argument length or filename expansion limits
# Note: additional filename arguments will be ignored
$ bundle exec bin/doimeta2es index --readdir=/path/to/all/metafiles

# Index a single metadata record from STDIN
$ cat /path/to/meta.xml | some-pipeline-processing | bundle exec bin/doimeta2es index --stdin

# Lookup a single DOI and index it, specify xml (or json)
$ bundle exec bin/doimeta2es lookup --doi=10.9999/abcd-efgh.123.456 --index --format=xml

# Lookup DOIs from a file (one per line), index them,
# and save their metadata to the default location /tmp/doimeta
$ bundle exec bin/doimeta2es lookup --file=/path/to/doi-list.txt --index --format=xml

# Lookup DOIs from a file (one per line), index them,
# and save them to an alternate directory $HOME/saved-doi-meta
$ bundle exec bin/doimeta2es lookup --file=/path/to/doi-list.txt --outputdir=$HOME/saved-doi-meta --index --format=xml

# Lookup DOIs from a file (one per line), index them but do not save metadata
$ bundle exec bin/doimeta2es lookup --file=/path/to/doi-list.txt --format=json --index --no-save

# Lookup DOIs from a file in batch, redirect successful and error output to files
$ bundle exec bin/doimeta2es lookup --file=/path/to/doi-list.txt --format=xml 1> successful-doi.log 2> fail-doi.log
```

## Library Usage
Useful functionality is exposed in `DOIMeta2ES::Transport` but to a large degree
merely wraps features present in `Elasticsearch`. Used in conjunction with
[`SimpleDOI`](https://github.com/UMNLibraries/simpledoi-ruby), a
`SimpleDOI::MetadataParser::Parser` can be directly indexed into Elasticsearch,
or a `String` containing metadata can be indexed.

```ruby
# Index a file from disk
meta_string = File.read('/path/to/doimeta.xml')

# Allow DOIMeta2ES to determine the metadata type and index it
doimeta = DOIMeta2ES::Transport.new
doimeta.index(meta_string)

# Pass in an Elasticsearch connection rather than use the default
es_client = Elasticsearch::Client.new 'http://elastic-host.example.com:9200'
doimeta = DOIMeta2ES::Transport.new(es_client)
doimeta.index(meta_string)

# Index an existing SimpleDOI::MetadataParser::Parser object
doi = SimpleDOI::DOI.new '10.9999/abcd.efg'
doi.lookup(SimpleDOI::UNIXREF_XML)

# Create a parser
parser = SimpleDOI::MetadataParser::UnixrefXMLParser.new(doi.body)

# Index it
doimeta.index(parser)
```

## Basic Configuration
Environment variables for configuration may be handled by Dotenv in a `.env`
file.

### Environment Variables
Variable                     | Default                  | Notes
-------------                | -------                  | -----
`ELASTICSEARCH_URL`          | `http://localhost:9200/` | Full URL of the Elasticsearch service to connect to

## Development
Copy `.env.example` to `.env` and modify your Elasticsearch URL if needed
```
$ bundle install
$ bundle exec rake test
```
