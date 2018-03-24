require_relative 'book_series'

module DOIMeta2ES
  class Adapter
    class BookChapter < BookSeries
      def prep_h
        super
        @hash.merge!(
          chapter: {
            title: @metadata_parser.chapter_title,
            chapter_number: @metadata_parser.chapter_number,
            pagination: @hash.delete(:pagination)
          }
        )
      end
    end
  end
end

