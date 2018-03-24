require_relative 'book'

module DOIMeta2ES
  class Adapter
    class BookSeries < Book
      def prep_h
        super
        @hash.merge!(series_title: @metadata_parser.book_series_title)
      end
    end
  end
end
