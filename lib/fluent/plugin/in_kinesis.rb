require 'aws-sdk-core'
require 'base64'
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

    config_param :stream_name,         :string
    config_param :shards,              :hash,   default: nil
    config_param :shard_iterator_type, :string, default: 'LATEST'
    config_param :sequence_number,     :string, default: nil

    config_param :tag, :string

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
      @running = true

      @threads = shard_iterators.map do |shard_id, shard_iterator|
        Thread.new { fetch(shard_id, shard_iterator) }
      end
    end

    def shutdown
      @running = false
      @threads.each(&:join)
    end

    private

    def fetch(shard_id, shard_iterator)
      while @running
        begin
          resp = @client.get_records(shard_iterator: shard_iterator)

          resp.each do |page|
            records = page[:records]
            emit_records(shard_id, records)
            shard_iterator = page[:next_shard_iterator]
          end

          sleep 1
        rescue => e
          log.warn(e.message)
        end
      end
    end

    def emit_records(shard_id, records)
      time = Time.now.to_i

      records.each do |record|
        record = record.to_h
        record[:shard_id] = shard_id
        record[:data] = Base64.strict_decode64(record[:data])
        Fluent::Engine.emit(@tag, time, record)
      end
    end

    def shard_iterators
      @shards = get_shards unless @shards

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
      end

      if @debug
        options.update(
          logger: Logger.new(log.out),
          log_level: :debug
        )
        # XXX: Add the following options, if necessary
        # :http_wire_trace => true
      end

      @client = Aws::Kinesis::Client.new(options)

    end
  end
end
