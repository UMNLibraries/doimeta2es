require 'minitest/autorun'
require_relative '../lib/adapter'
require_relative 'mock_parser'

module DOIMeta2ES
  module Test
    class AdapterTest < Minitest::Test
      def setup
      end

      def test_initialize
        assert_raises ArgumentError do
          Adapter.new "A String not a MetadataParser object"
        end

        parser = SimpleDOI::MetadataParser::MockParser.new "some metadata"
        parser.identifier = :book?
        # Note these assertions are against strings rather than constants because the constants are private
        # and therefore can't be named here without Ruby complaining. Whatever, it's just a unit test.
        adapter = Adapter.new parser
        assert_equal 'Book', adapter.type

        parser.identifier = :journal_article?
        # Note these assertions are against strings rather than constants because the constants are private
        # and therefore can't be named here without Ruby complaining. Whatever, it's just a unit test.
        adapter = Adapter.new parser
        assert_equal 'JournalArticle', adapter.type
      end

      def test_target_index
        parser = SimpleDOI::MetadataParser::MockParser.new "some metadata"
        
        [:book?, :book_chapter?, :book_series?].each do |method|
          parser.identifier = method
          adapter = Adapter.new parser
          assert_equal 'book', adapter.target_index
        end
        [:journal?, :journal_article?, :conference_proceeding?].each do |method|
          parser.identifier = method
          adapter = Adapter.new parser
          assert_equal 'article', adapter.target_index
        end
      end

      def test_issns
        parser = SimpleDOI::MetadataParser::MockParserWithoutMultiissnsMethod.new "some metadata"
        adapter = Adapter.new parser
        assert_equal [{:issn=>"1234-5678", :format=>"print"}, {:issn=>"9876-5432", :format=>"electronic"}], adapter.issns

        parser = SimpleDOI::MetadataParser::MockParserWithMultiissnsMethod.new "some metadata"
        adapter = Adapter.new parser
        assert_equal [{:issn=>"1234-5678", :format=>"n/a"}, {:issn=>"9876-5432", :format=>"n/a"}], adapter.issns
      end

      def test_isbns
        parser = SimpleDOI::MetadataParser::MockParserWithoutMultiissnsMethod.new "some metadata"
        adapter = Adapter.new parser
        assert_equal [{:isbn=>"9781111111111", :format=>"print"}, {:isbn=>"9789999999999", :format=>"electronic"}], adapter.isbns

        parser = SimpleDOI::MetadataParser::MockParserWithMultiissnsMethod.new "some metadata"
        adapter = Adapter.new parser
        assert_equal [{:isbn=>"9781111111111", :format=>"n/a"}, {:isbn=>"9789999999999", :format=>"n/a"}], adapter.isbns
      end
    end
  end
end
