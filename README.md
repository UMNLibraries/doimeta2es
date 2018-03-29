# DOIMeta2ES - Index DOI metadata into Elasticsearch

## Installation
```shell
$ bundle install
```

## Command line usage
The executable `bin/doimeta2es` may be used to index metadata filesl (XML or 
JSON) on disk or to lookup a DOI's metadata and optionally index it.

```shell
# Bulk indexing of files on disk
# Note: this gets slow with tens of thousands of files, and may
# even exceed shell expansion limits
#
# --batchsize default is 100
# Add --verbose to see transactions with Elasticsearch
$ bundle exec bin/doimeta2es index --batchsize=1000 /path/to/metadata/files/*.xml

# Index a single metadata record from STDIN
$ cat /path/to/meta.xml | some-pipeline-processing | bundle exec bin/doimeta2es index --stdin

# Lookup a single DOI and index it
$ bundle exec bin/doimeta2es lookup --doi=10.9999/abcd-efgh.123.456 --index
```
