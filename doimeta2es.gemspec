# -*- encoding: utf-8 -*-
$:.push File.expand_path(File.join('..', 'lib'), __FILE__)
require_relative 'lib/doimeta2es/version'

Gem::Specification.new do |spec|
  spec.name          = 'doimeta2es'
  spec.version       = DOIMeta2ES::VERSION
  spec.platform      = Gem::Platform::RUBY
  spec.authors       = %w(Michael Berkowski)
  spec.email         = %w(libwebdev@umn.edu)
  spec.homepage      = ''
  spec.summary       = 'DOI metadata indexing bridge to Elasticsearfch'
  spec.description   = 'Provides glue to index previously retrieved DOI metadata as Citeproc JSON or Unixref XML into Elasticsearch'

  spec.files         = `git ls-files`.split("\n")
  spec.test_files    = `git ls-files -- test/*`.split("\n")
  spec.executables   = []
  spec.require_paths = %w(lib)

  spec.add_development_dependency 'minitest'
end
