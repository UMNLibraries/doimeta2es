module SimpleDOI
  module MetadataParser
    class MockParser < Parser
      # Just junk the whole initializer. Not needed for these tests, we just need an object that is_a? SimpleDOI::MetadataParser::Parser subclass
      # so Adapter#initalize can succeed
      def initialize(str)
        # Default journal_article? used for on-the-fly inspector methods
        @identifier = :journal_article?
      end
      # A setter that receives values like :book?, :journal_article?, :conference_proceeding?
      # so an instance of this class can be made to return true for an arbitray type
      # Instantiate it then set obj.identifier = :book so book? returns true
      attr_writer :identifier

      # Redefine each of the boolean identifier methods a Parser would have 
      # to just return true if matching the name of the identifer method
      DOIMeta2ES::Adapter::IDENTIFIER_METHODS.each do |methname|
        define_method methname do
          @identifier == methname
        end
      end
    end

    class MockParserWithoutMultiissnsMethod < MockParser
      def isbn; '9781111111111'; end
      def eisbn; '9789999999999'; end
      def issn; '1234-5678'; end
      def eissn; '9876-5432'; end
    end
    class MockParserWithMultiissnsMethod < MockParser
      def issns; ['1234-5678','9876-5432']; end
      def isbns; ['9781111111111','9789999999999']; end
    end
  end
end
