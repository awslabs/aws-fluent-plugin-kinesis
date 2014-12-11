require 'aws-sdk-core'
require 'gdbm'
require 'multi_json'
require 'logger'
require 'fluent/plugin/version'

module FluentPluginKinesis
  class Input < Fluent::Input
    USER_AGENT_NAME = 'fluent-plugin-kinesis-input'

    STARTING_SEQUENCE_NUMBER_TYPES = %w(
      AFTER_SEQUENCE_NUMBER
      AT_SEQUENCE_NUMBER
    )

    NO_STARTING_SEQUENCE_NUMBER_TYPES = %w(
      LATEST
      TRIM_HORIZON
    )

    SHARD_ITERATOR_TYPES =
      STARTING_SEQUENCE_NUMBER_TYPES +
      NO_STARTING_SEQUENCE_NUMBER_TYPES

    Fluent::Plugin.register_input('kinesis',self)

    config_param :aws_key_id,  :string, default: nil
    config_param :aws_sec_key, :string, default: nil
    config_param :region,      :string, default: nil

    config_param :profile,          :string, :default => nil
    config_param :credentials_path, :string, :default => nil

    config_param :stream_name,         :string
    config_param :shards,              :hash,   default: nil
    config_param :shard_iterator_type, :string, default: 'LATEST'

    config_param :tag,      :string
    config_param :interval, :integer, default: 1
    config_param :db,       :string,  default: nil

    config_param :json_data, :bool, default: false

    config_param :debug, :bool, default: false

    def configure(conf)
      super
      @shard_iterator_type.upcase!

      unless SHARD_ITERATOR_TYPES.include?(@shard_iterator_type)
        raise Fluent::ConfigError, "'shard_iterator_type' must be one of the following values: #{SHARD_ITERATOR_TYPES.join(',')}"
      end
    end

    def start
      super
      load_client

      @db = GDBM.open(@db) if @db
      @loop = Coolio::Loop.new

      shard_iterators.map do |shard_id, shard_iterator|
        timer = TimerWatcher.new(@interval, true, log) do
          shard_iterator = fetch(shard_id, shard_iterator)
        end

        @loop.attach(timer)
      end

      @thread = Thread.new(&method(:run))
    end

    def shutdown
      @loop.stop
      @thread.join
      @db.close if @db
    end

    private

    def run
      @loop.run
    rescue => e
      @log.error(e.message)
      @log.error_backtrace(e.backtrace)
    end

    def fetch(shard_id, shard_iterator)
      resp = @client.get_records(shard_iterator: shard_iterator)
      seq_num = nil

      resp.each do |page|
        records = page[:records]
        seq_num = records.last[:sequence_number] if records.last
        emit_records(shard_id, records)
        shard_iterator = page[:next_shard_iterator]
      end

      if @db and seq_num
        @db[shard_id] = seq_num
      end

      shard_iterator
    end

    def emit_records(shard_id, records)
      time = Time.now.to_i

      records.each do |record|
        record = record.to_h
        record[:shard_id] = shard_id

        if @json_data
          begin
            json = JSON.parse(record[:data])
            record.update(json)
            record.delete(:data)
          rescue JSON::ParserError => e
            @log.warn(e.message)
            @log.warn_backtrace(e.backtrace)
          end
        end

        tag = @tag.gsub(/\${([^}]+)}/) { record[$1] }
        Fluent::Engine.emit(tag, time, record)
      end
    end

    def shard_iterators
      @shards = get_shards unless @shards
      @shards.update(shards_from_store)

      @shards.map do |shard_id, starting_sequence_number|
        params = {
          stream_name: @stream_name,
          shard_id: shard_id,
          shard_iterator_type: @shard_iterator_type.upcase,
        }

        if STARTING_SEQUENCE_NUMBER_TYPES.include?(@shard_iterator_type)
          params[:starting_sequence_number] = starting_sequence_number
        end

        resp = @client.get_shard_iterator(params)

        [shard_id, resp[:shard_iterator]]
      end
    end

    def shards_from_store
      shards = {}

      if @db
        @db.each do |shard_id, sequence_number|
          shards[shard_id] = sequence_number
        end
      end

      shards
    end

    def get_shards
      seq_num_by_shard_id = {}
      resp = @client.describe_stream(stream_name: @stream_name)

      resp.each do |page|
        page.stream_description.shards.each do |shard|
          shard_id = shard.shard_id
          seq_num = shard.sequence_number_range.starting_sequence_number
          seq_num_by_shard_id[shard_id] = seq_num
        end
      end

      seq_num_by_shard_id
    end

    def load_client

      user_agent_suffix = "#{USER_AGENT_NAME}/#{FluentPluginKinesis::VERSION}"

      options = {
        user_agent_suffix: user_agent_suffix
      }

      if @region
        options[:region] = @region
      end

      if @aws_key_id && @aws_sec_key
        options.update(
          access_key_id: @aws_key_id,
          secret_access_key: @aws_sec_key,
        )
      elsif @profile
        credentials_opts = {:profile_name => @profile}
        credentials_opts[:path] = @credentials_path if @credentials_path
        credentials = Aws::SharedCredentials.new(credentials_opts)
        options[:credentials] = credentials
      end

      if @debug
        options.update(
          logger: Logger.new(log.out),
          log_level: :debug,
        )
        # XXX: Add the following options, if necessary
        # :http_wire_trace => true
      end

      @client = Aws::Kinesis::Client.new(options)

    end

    class TimerWatcher < Coolio::TimerWatcher
      def initialize(interval, repeat, log, &callback)
        @callback = callback
        @log = log
        super(interval, repeat)
      end

      def on_timer
        @callback.call
      rescue => e
        @log.error(e.message)
        @log.error_backtrace(e.backtrace)
      end
    end
  end
end
