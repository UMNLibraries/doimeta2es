require_relative 'journal_article'

module DOIMeta2ES
  class Adapter
    class ConferenceProceeding < JournalArticle
      def prep_h
        super
        @hash.merge!( 
          full_title: @metadata_parser.conference_title,
          series_title: @metadata_parser.conference_series_title
        )
      end
    end
  end
end
