require_relative 'journal'

module DOIMeta2ES
  class Adapter
    class JournalArticle < Journal
      def prep_h
        super
        @hash.merge!({
          article: {
            title: @metadata_parser.article_title,
            pagination: @hash.delete(:pagination),
            # Moves authors inside
            authors: @hash.delete(:contributors)
          }
        })
      end
    end
  end
end
