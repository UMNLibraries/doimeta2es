require 'json'
require 'fileutils'

module DOIMeta2ES
  # Class to invoke primary Transport operations
  # This class' purpose is as a middle-ground between bin/doimeta2es Thor CLI file
  # and testable actions
  #
  # All public Runner methods map to CLI commands defined in bin/doimeta2es and
  # accept an options Hash. For information on available options, see Thor option/CLI flag
  # definitions in bin/doimeta2es
  class Runner
    attr_writer :es_client, :outstream, :errstream, :instream
    def initialize(es_client)
      @es_client = es_client

      # Default to stdio streams, can be overwritten with writer methods
      @outstream = $stdout
      @errstream = $stderr
      @instream = $stdin
    end

    # Indexes single or batch metadata files
    # When the stdin option is truthy, read one metadata file from @instream
    # When the readdir option is present, recursively read all xml,json files from the specified dir
    # When individual files are specified on the command line, index them
    def index(options={}, *files) 
      transport = DOIMeta2ES::Transport.new @es_client

      if options[:readdir] && !files.empty?
        @outstream.puts 'Directory was provided with --readdir, ignoring additional file arguments'
      end

      if options[:stdin]
        report = transport.index @instream.read
      elsif options[:readdir]
        readdir = File.expand_path options[:readdir]
        # Glob for all files matching valid format extensions
        dirfiles = Dir.glob("#{readdir}/**/*.{#{formats.keys.join(',')}}")
        report = transport.index_batch dirfiles, (options[:batchsize] || 100)
      else
        report = transport.index_batch files, (options[:batchsize] || 100)
      end
      @outstream.puts report.to_json if options[:verbosity] > 0
      nil
    end

    # Lookup one or more DOIs and index them if requested
    # When the doi option is present, lookup ONE DOI
    # When the file option is present, lookup each DOI listed in file
    # When the index option is truthy, send looked up metadata to the Elasticsearch index
    # When the save option is truthy, save metadata files to outputdir
    def lookup(options={})
      if options[:doi] && options[:file]
        raise ArgumentError.new("Options --doi and --file are mutually exclusive")
      end

      raise ArgumentError.new("--format must be one of #{formats.keys.join(', ')}") unless formats.keys.include?(options[:format])

      if options[:index]
        transport = DOIMeta2ES::Transport.new @es_client
      end

      # Single DOI passed
      if options[:doi]
        begin
          doi = SimpleDOI::DOI.new(options[:doi].strip)
          doi.lookup formats[options[:format]]
          # Dump the returned string unless we will directly index it
          @outstream.puts doi.body unless (doi.body.to_s.strip.empty? || options[:index]) rescue nil

          if options[:index]
            transport.index(doi.body)
          end
        rescue ArgumentError
          @errstream.puts "Invalid DOI: #{options[:doi].strip}"
        rescue StandardError => e
          # A network lookup error of some kind from Curl
          @errstream.puts "Failed lookup: #{doi.to_s}"
          @errstream.puts "Network error occurred: #{e.message}"
          @errstream.puts e.backtrace.join("\n") if options[:verbosity] > 0
        end

      # File of DOIs passed
      elsif options[:file]
        File.readlines(options[:file].strip).each do |line|
          begin
            doi = SimpleDOI::DOI.new(line.strip)
          rescue ArgumentError
            @errstream.puts "Invalid DOI: #{line.strip}"
            next
          end

          begin
            doi.lookup formats[options[:format]]
            if doi.body.to_s.strip.empty?
              @errstream.puts "Failed batch lookup: #{doi.to_s}"
              next
            end
            @outstream.puts "Successful batch lookup: #{doi.to_s}"
            if options[:save]
              saved = save_meta(doi, options[:format], options[:outputdir], doi.body)
              @outstream.puts "Saved metadata file: #{saved}" if options[:verbosity] > 0
            end

            if options[:index]
              transport.index(doi.body)
            end
          rescue Curl::Err::CurlError => e
            # A network lookup error of some kind from Curl
            @errstream.puts "Failed batch lookup: #{doi.to_s}"
            @errstream.puts "Network error occurred: #{e.message}"
            @errstream.puts e.backtrace.join("\n") if options[:verbosity] > 0
            next
          rescue StandardError => e
            @errstream.puts "Failed batch lookup: #{doi.to_s}"
            @errstream.puts e.message
            @errstream.puts e.backtrace.join("\n") if options[:verbosity] > 0
            next
          end
          @errstream.flush
          @outstream.flush
        end
      else
        raise ArgumentError.new("You must specify a single doi with --doi or input file with --file")
      end
      nil
    end

    # Create or update Elasticsearch indices and mappings
    def setup(index_defs_path, options={})
      # Make an array of either a single index if requested options or all indexes defined in index-defs/index
      indexes = if options[:index]
        File.exists?("#{index_defs_path}/index/#{options[:index]}.json") ? [options[:index]] : []
      else
        Dir.glob("#{index_defs_path}/index/*.json").map{|i| File.basename(i, ".json")}
      end
      if indexes.empty?
        @errstream.puts "No compatible index definitions found in #{index_defs_path}/index"
        return
      end

      # Load each index and corresponding mapping
      indexes.each do |idx|
        begin
          idxfile = File.expand_path("#{index_defs_path}/index/#{idx}.json")
          mappingfile = File.expand_path("#{index_defs_path}/mapping/#{idx}.json")

          begin
            @outstream.puts "Creating index #{idx} from #{idxfile}"
            @es_client.indices.create index: idx, body: File.read(idxfile)
          rescue Elasticsearch::Transport::Transport::Errors::BadRequest => e
            @errstream.puts es_error_json e
          end
          @outstream.puts "Creating mapping #{idx} from #{mappingfile}"
          @es_client.indices.put_mapping index: idx, type: idx, body: File.read(mappingfile), include_type_name: true
        rescue StandardError => e
          @errstream.puts es_error_json e
        end
      end
      nil
    end

    private
    def es_error_json(e)
      JSON.parse(e.message.split(' ', 2).pop)
    end

    def formats
      formats = {
        'json' => SimpleDOI::CITEPROC_JSON,
        'xml' => SimpleDOI::UNIXREF_XML
      }
      formats.default = SimpleDOI::CITEPROC_JSON
      formats
    end

    # Saves metadata to a CGI-escaped, DOI prefixed directory
    # Returns the path to the new file
    def save_meta(doi, extension, dir, metadata)
      save_dir = "#{dir}/#{extension}/#{CGI.escape(doi.prefix)}"
      FileUtils.mkdir_p save_dir
      meta_file = "#{save_dir}/#{CGI.escape(doi.to_s)}.#{extension}"
      File.open(meta_file, 'w') { |file| file.write metadata }
      meta_file
    end
  end
end
