require 'minitest/autorun'
require_relative '../lib/transport'

module DOIMeta2ES
  module Test
    class TransportTest < Minitest::Test
      def setup
      end

      def fixture_path
        File.expand_path(File.dirname(__FILE__) + '/../tests/fixtures')
      end

      def test_parser_from_file
        assert_kind_of SimpleDOI::MetadataParser::CiteprocJSONParser, Transport.parser_from_file("#{fixture_path}/citeproc-book-2.json")
        assert_kind_of SimpleDOI::MetadataParser::UnixrefXMLParser, Transport.parser_from_file("#{fixture_path}/unixref-book-2.xml")

        assert_raises NoParserFoundError do
          Transport.parser_from_file("#{fixture_path}/invalid-book.txt")
        end
      end

      def test_parser_from_string
        str = File.read("#{fixture_path}/citeproc-book-2.json")
        assert_kind_of SimpleDOI::MetadataParser::CiteprocJSONParser, Transport.parser_from_string(str)

        str = File.read("#{fixture_path}/unixref-book-2.xml")
        assert_kind_of SimpleDOI::MetadataParser::UnixrefXMLParser, Transport.parser_from_string(str)

        str = File.read("#{fixture_path}/invalid-book.txt")
        assert_raises NoParserFoundError do
          Transport.parser_from_string(str)
        end
      end

      def test_initialize
        assert_raises ArgumentError do
          Transport.new "Not an Elasticsearch client"
        end
      end
    end
  end
end
