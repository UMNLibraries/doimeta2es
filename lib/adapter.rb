require 'simple_doi'
require 'date'
Dir[File.expand_path(File.join(File.dirname(__FILE__), 'adapter', '*.rb'))].each { |f| require_relative f }

module DOIMeta2ES
  class Adapter
    CLEANUP_KEYS = [
      :journal_title,
      :journal_isoabbrev_title,
      :article_title,
      :book_title,
      :book_series_title,
      :chapter_title,
      :chapter_number,
      :conference_title,
      :conference_series_title,
      :issn,
      :eissn,
      :isbn,
      :eisbn,
    ].freeze

    private_constant :Journal, :JournalArticle, :Book, :BookSeries, :BookChapter, :ConferenceProceeding
    attr_reader :adapter_class

    def initialize(metadata_parser)
      raise ArgumentError.new('Argument must be a SimpleDOI::MetadataParser::Parser subclass') unless metadata_parser.is_a? SimpleDOI::MetadataParser::Parser

      # Map boolean type tests to a type subclass name & constantize
      # e.g. transforms :journal_article? to const class JournalArticle if true
      @metadata_parser = metadata_parser
      [
        :journal_article?,
        :journal?,
        :book?,
        :book_series?,
        :book_chapter?,
        :conference_proceeding?
      ].each { |meth| @adapter_class = self.class.const_get(meth.to_s.sub('?','').split('_').map { |w| w.capitalize }.join) if @metadata_parser.send(meth) }
      @adapter_class ||= self.class
    end

    def target_index
      @metadata_parser.book? || @metadata_parser.book_series? || @metadata_parser.book_chapter? ? 'book' : 'article'
    end

    def to_h
      @hash = subtype.prep_h
      cleanup
      @hash
    end

    def cleanup(additional_keys=[])
      (CLEANUP_KEYS + additional_keys).uniq.map { |k| @hash.delete(k) }
      @hash
    end

    def to_json
      to_h.to_json
    end

    def issns
      # Convert a flat list of issns into hashes of issn, format (n/a format)
      begin
        @metadata_parser.issns.map { |i| { issn: i, format: 'n/a' } }
      rescue NoMethodError
        issns = []
        issns.push({issn: @metadata_parser.issn, format: 'print'}) if @metadata_parser.issn
        issns.push({issn: @metadata_parser.eissn, format: 'electronic'}) if @metadata_parser.eissn
        issns
      end
    end

    def isbns
      # Convert a flat list of isbns into hashes of isbn, format (n/a format)
      begin
        @metadata_parser.isbns.map { |i| { isbn: i, format: 'n/a' } }
      rescue NoMethodError
        isbns = []
        isbns.push({isbn: @metadata_parser.isbn, format: 'print'}) if @metadata_parser.isbn
        isbns.push({isbn: @metadata_parser.eisbn, format: 'electronic'}) if @metadata_parser.eisbn
        isbns
      end
    end

    protected
    def subtype
      @subtype ||= adapter_class.new(@metadata_parser)
    end

    def prep_h
      @hash = @metadata_parser.to_h
      @hash = @hash.merge(
        issns: issns,
        isbns: isbns,
        meta_date: DateTime.now
      )
      @hash[:contributors].map! { |c|
        c.merge(
          name: {
            given: c.delete(:given_name),
            surname: c.delete(:surname),
          },
          first_author: c[:sequence].to_i == 1
        )
      }
      @hash
    end
  end
end
