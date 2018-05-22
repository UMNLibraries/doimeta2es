require 'curb'
require 'elasticsearch'
require 'cgi'
require 'dotenv/load'

module DOIMeta2ES
  class Transport
    def initialize(es=nil)
      raise ArgumentError.new('es must be an Elasticsearch::Client') if es && !es.kind_of?(Elasticsearch::Transport::Client)

      # Connect to the supplied client or ENV-specified or localhost
      # As long as Dotenv has loaded, it is not actually necessary to read ENV & default to localhost:9200
      # This is ES' default behavior and it would do the same thing anyway, but being explicit here to avoid confusion
      @es = es || (Elasticsearch::Client.new url: (ENV['ELASTICSEARCH_URL'] || 'http://localhost:9200'))
    end

    def index(str)
      begin
        meta = self.class.parser_from_string str
        adapter = Adapter.new meta
        result = @es.index index: adapter.target_index, type: adapter.target_index, id: meta.doi.upcase, body: adapter.to_json
      rescue NoParserFoundError => e
        puts e.inspect
      rescue StandardError => e
      end
    end

    def index_batch(filenames=[], batch_size=100)
      report = Hash.new(0)
      report[:errors] = []
      begin
        filenames.each_slice(batch_size) do |batch|
          begin
            bulk_body = []
            batch.each do |infile|
              begin
                meta = self.class.parser_from_file(infile)
                adapter = Adapter.new meta
                idx = adapter.target_index

                # Add a hash from this parsed document to the bulk action's array
                bulk_body << {index: {_index: idx, _type: idx, _id: meta.doi.upcase, data: adapter.to_h }}
                report[idx.to_sym] += 1
              rescue Errno::ENOENT
                report[:errors] << "File #{infile} is unreadable or does not exist"
              rescue StandardError => e
                report[:errors] << "An error occurred with file #{infile}: #{e.message}"
                next
              end
            end
            # Write the batch into the index
            @es.bulk(body: bulk_body)
          rescue StandardError => e
            report[:errors] << "A batch error occurred: #{e.message}"
            next
          end
        end
      rescue StandardError => e
        report[:errors] << "An error occurred: #{e.message}"
      end
      report
    end

    # Return a MetadataParser class from file extension
    def self.parser_from_file(filename)
      {
        '.json' => SimpleDOI::MetadataParser::CiteprocJSONParser,
        '.xml'  => SimpleDOI::MetadataParser::UnixrefXMLParser
      }[File.extname(filename)].new(File.read(filename))
    end

    # Return a MetadataParser class by inspecting an input string's
    # identifying characters
    def self.parser_from_string(instr)
      str = instr.strip
      # {} is going to be a JSON attempt
      # <!xml is going ot be an XML attempt
      #
      # This passes an array of specific character indexes (or range) to compare against
      # a joined string of those characters. Makes it possible to check the first & last
      # for one case while checking a range for a different case. It's weird, but probably
      # ok and much faster than invoking a JSON parser or XML parser to test these.
      #
      # TODO: Put this into SimpleDOI itself as a static method instead of here
      {
        SimpleDOI::MetadataParser::CiteprocJSONParser => [[0, str.length-1], '{}'],
        SimpleDOI::MetadataParser::UnixrefXMLParser => [(0..4), '<?xml']
      }.map { |type,insp| return type.new(str) if str.chars.values_at(*insp.first).join == insp.last }
      raise NoParserFoundError.new 'No available MetadatParser to handle input string'
    end
  end

  class NoParserFoundError < StandardError; end;
end
