module DOIMeta2ES
  class Adapter
    class Book < DOIMeta2ES::Adapter
      def prep_h
        super
        @hash.merge!(full_title: @metadata_parser.book_title)
      end
    end
  end
end
