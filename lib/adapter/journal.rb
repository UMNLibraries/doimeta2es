require_relative '../adapter'

module DOIMeta2ES
  class Adapter
    class Journal < DOIMeta2ES::Adapter
      def prep_h
        super
        @hash.merge!({
          full_title: @metadata_parser.journal_title,
          abbrev_title: @metadata_parser.journal_isoabbrev_title
        })
      end
    end
  end
end
