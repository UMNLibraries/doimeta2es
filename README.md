# DOIMeta2ES - Index DOI metadata into Elasticsearch

## Installation
```shell
$ bundle install
```

## Command line usage
The executable `bin/doimeta2es` may be used to index metadata filesl (XML or
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
# --batchsize default is 100
# Add --verbose to see transactions with Elasticsearch
$ bundle exec bin/doimeta2es index --batchsize=1000 /path/to/metadata/files/*.xml

# Index a single metadata record from STDIN
$ cat /path/to/meta.xml | some-pipeline-processing | bundle exec bin/doimeta2es index --stdin

# Lookup a single DOI and index it, specify xml (or json)
$ bundle exec bin/doimeta2es lookup --doi=10.9999/abcd-efgh.123.456 --index --format=xml
```

## Basic Configuration
Environment variables for configuration may be handled by Dotenv in a `.env`
file.

### Environment Variables
Variable                     | Default                  | Notes
-------------                | -------                  | -----
`ELASTICSEARCH_URL`          | `http://localhost:9200/` | Full URL of the Elasticsearch service to connect to

## Testing
```
$ bundle exec rake test
```
