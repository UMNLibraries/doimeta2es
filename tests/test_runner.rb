require 'minitest/autorun'
require 'webmock'
require 'webmock/minitest'
require 'fileutils'
require_relative '../lib/runner'

module DOIMeta2ES
  module Test
    class RunnerTest < Minitest::Test
      WebMock.disable_net_connect!

      def setup
        @tempdir = nil;
        @stubs = {
          # TODO Delete all files from /tmp

          # WebMock stubs for metadata lookup reponses
          # Add more stubs as hash keys to reference later
          get_107589_json: stub_request(:get, 'https://doi.org/10.7589%2F2017-03-057')
            .with( headers: { 'Accept' => 'application/vnd.citationstyles.csl+json' })
            .to_return(
              body: File.new("#{fixture_meta_path}/10.7589%2F2017-03-057.json"),
              status: 200,
              headers: { 'content-type' => 'application/citeproc+json' }
            ),
          get_107589_xml: stub_request(:get, 'https://doi.org/10.7589%2F2017-03-057')
            .with(headers: { 'Accept' => 'application/vnd.crossref.unixref+xml' })
            .to_return(
              body: File.new("#{fixture_meta_path}/10.7589%2F2017-03-057.xml"),
              status: 200,
              headers: { 'content-type' => 'application/unixref+xml' }
            ),
          get_109999123: stub_request(:get, 'https://doi.org/10.9999%2F123')
            .to_return(
              body: File.new("#{fixture_meta_path}/10.9999%2F123.xml"),
              status: 200,
              headers: { 'content-type' => 'application/unixref+xml' }
            ),
          get_109999456: stub_request(:get, 'https://doi.org/10.9999%2F456')
            .to_return(
              body: File.new("#{fixture_meta_path}/10.9999%2F456.xml"),
              status: 200,
              headers: { 'content-type' => 'application/unixref+xml' }
            ),
          # A bad DOI returns a 404
          get_109999999: stub_request(:get, 'https://doi.org/10.9999%2F999')
            .to_return(
              body: '',
              status: 404
            ),
          put_107589: stub_request(:put, %r{elasticmock\.local:9299/article/_doc/10.7589%2F2017-03-057}),
          put_109999123: stub_request(:put, %r{elasticmock\.local:9299/article/_doc/10.9999%2F123}),
          put_109999456: stub_request(:put, %r{elasticmock\.local:9299/article/_doc/10.9999%2F456}),
          post_bulk_single: stub_request(:post, %r{elasticmock\.local:9299/_bulk})
            .to_return(
              body: ({errors: [], article: 1}).to_json,
              status: 201
            ),
          # Multi index will be done with batchsize=2 and 3 args, thus 2 calls
          post_bulk_multi: stub_request(:post, %r{elasticmock\.local:9299/_bulk})
            .to_return(
               body: ({errors: [], article: 3}).to_json,
               status: 201
            ),
        }
      end

      def teardown
        # Delete all files from /tmp
        FileUtils.rm_rf @tempdir if @tempdir
        @tempdir = nil

        WebMock.reset_executed_requests!
      end

      def fixture_path
        self.class.fixture_path
      end

      def fixture_meta_path
        self.class.fixture_meta_path
      end

      def self.fixture_meta_path
        "#{fixture_path}/meta"
      end

      def self.fixture_path
        "#{File.dirname(__FILE__)}/fixtures"
      end

      def output_tmp_path
        @tempdir ||= Dir.mktmpdir("doimeta2es-test")
      end

      def es_client
        Elasticsearch::Client.new(url: 'http://elasticmock.local:9299')
      end

      def runner
        runner = DOIMeta2ES::Runner.new(es_client)
        # For a test Runner obj, we will use capture_io and can deal
        # easily directly with stdout/stderr
        runner.outstream = $stdout
        runner.errstream = $stderr
        # But stdin isn't handled by capture_io, so create a fake one
        runner.instream = MockStdinJSON.new
        runner
      end

      def test_index_single_file_quiet
        options = {
          verbosity: 0
        }
        out, = capture_io do
          runner.index(options, "#{fixture_meta_path}/10.7589%2F2017-03-057.xml")
        end

        assert_requested @stubs[:post_bulk_single]
        assert_equal '', out.strip, 'verbosity=0 should show no output errors, articles report'
      end

      def test_index_single_file_xml
        options = {
          verbosity: 1
        }
        out, = capture_io do
          runner.index(options, "#{fixture_meta_path}/10.7589%2F2017-03-057.xml")
        end

        assert_equal ({errors: [], article: 1}).to_json, out.strip, 'verbosity=1 should show JSON output errors, articles report'
      end

      def test_index_multi_files
        options = {
          batchsize: 2,
          verbosity: 1
        }
        out, = capture_io do
          file_args = [
            "#{fixture_meta_path}/10.7589%2F2017-03-057.xml",
            "#{fixture_meta_path}/10.9999%2F123.xml",
            "#{fixture_meta_path}/10.7589%2F2017-03-057.json",
          ]
          runner.index(options, *file_args)
        end

        # Bulk insert will be called twice with batchsize=2
        assert_requested @stubs[:post_bulk_multi], times: 2
        assert_equal ({errors: [], article: 3}).to_json, out.strip, 'verbosity=1 should show JSON output errors, articles report'
      end

      def test_index_readdir
        options = {
          readdir: fixture_meta_path,
          verbosity: 1,
        }

        out, = capture_io do
          runner.index(options)
        end

        assert_equal ({errors: [], article: 5}).to_json, out.strip, 'verbosity=1 should show 5 items indexed'
      end

      def test_index_stdin
        options = {
          stdin: true,
          verbosity: 1
        }

        capture_io do
          runner.index(options)
        end

        assert_requested @stubs[:put_107589]
      end

      def test_lookup_with_index_xml
        options = {
          index: true,
          doi: '10.7589/2017-03-057',
          format: 'xml',
          verbosity: 0
        }
        out, = capture_io do
          runner.lookup(options)
        end

        # Output should include full JSON
        # Output should not include XML
        assert_equal '', out, "STDOUT should be empty when lookup called with --index"

        # Ensure PUT was called for indexing
        assert_requested @stubs[:put_107589]
      end

      def test_lookup_without_index
        options = {
          doi: '10.7589/2017-03-057',
          format: 'json',
          index: false,
          verbosity: 0
        }
        out, = capture_io do
          runner.lookup(options)
        end
        # Output should include full JSON
        assert_equal File.read("#{fixture_meta_path}/10.7589%2F2017-03-057.json"), out, "STDOUT should contain JSON metadata"

        # PUT request should NOT have been called
        refute_requested @stubs[:put_107589]
      end

      def test_batch_lookup_file_save_meta_no_index
        options = {
          file: "#{fixture_path}/doi-list.txt",
          format: 'xml',
          index: false,
          outputdir: output_tmp_path,
          save: true,
          verbosity: 1
        }
        out, err = capture_io do
          runner.lookup(options)
        end

        # PUT should NOT be called
        refute_requested @stubs[:put_109999123]
        refute_requested @stubs[:put_109999456]

        # File should exist
        assert File.exist?("#{@tempdir}/xml/10.9999/10.9999%2F123.xml"), 'Metadata files should be saved to outputdir'
        assert File.exist?("#{@tempdir}/xml/10.9999/10.9999%2F456.xml"), 'Metadata files should be saved to outputdir'
        refute File.exist?("#{@tempdir}/xml/10.9999/10.9999%2F999.xml"), 'Invalid lookup should not save metadata to outputdir'

        # Basic stdout output for verbosity=1
        assert_match %r{Successful batch lookup: 10.9999/123}, out, 'verbosity>=0 should output batch lookup DOI'
        assert_match %r{Successful batch lookup: 10.9999/456}, out, 'verbosity>=0 should output batch lookup DOI'
        assert_match %r{Failed batch lookup: 10.9999/999}, err, 'verbosity>=0 should output batch lookup DOI failure'

        assert_match %r{Saved metadata file:.+xml/10.9999/10.9999%2F123\.xml}, out, 'verbosity=1 should output metadata save location'
        assert_match %r{Saved metadata file:.+xml/10.9999/10.9999%2F456\.xml}, out, 'verbosity=1 should output metadata save location'
      end

      def test_batch_lookup_file_nosave_meta
        options = {
          file: "#{fixture_path}/doi-list.txt",
          format: 'xml',
          index: true,
          outputdir: output_tmp_path,
          save: false,
          verbosity: 0
        }
        out, err = capture_io do
          runner.lookup(options)
        end

        # PUT should be called
        assert_requested @stubs[:put_109999123]
        assert_requested @stubs[:put_109999456]

        # Metadata file should not exist
        refute File.exist?("#{@tempdir}/xml/10.9999/10.9999%2F123.xml"), 'Metadata files should NOT be saved to outputdir'
        refute File.exist?("#{@tempdir}/xml/10.9999/10.9999%2F456.xml"), 'Metadata files should NOT be saved to outputdir'

        assert_match %r{Successful batch lookup: 10.9999/123}, out, 'verbosity>=0 should output batch lookup DOI'
        assert_match %r{Successful batch lookup: 10.9999/456}, out, 'verbosity>=0 should output batch lookup DOI'
        assert_match %r{Failed batch lookup: 10.9999/999}, err, 'verbosity>=0 should output batch lookup DOI failure'
      end

      # Override a stdin read method
      class MockStdinJSON < StringIO
        def read
          # Return the file contents of one of our fixture DOI metas
          File.read "#{RunnerTest.fixture_meta_path}/10.7589%2F2017-03-057.json"
        end
      end
    end
  end
end
