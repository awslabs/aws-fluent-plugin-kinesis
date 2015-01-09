require 'aws-sdk-core'
require 'base64'
require 'multi_json'
require 'logger'
require 'securerandom'
require 'fluent/plugin/version'

module FluentPluginKinesis
  class OutputFilter < Fluent::BufferedOutput

    include Fluent::DetachMultiProcessMixin
    include Fluent::SetTimeKeyMixin
    include Fluent::SetTagKeyMixin

    USER_AGENT_NAME = 'fluent-plugin-kinesis-output-filter'
    PROC_BASE_STR = 'proc {|record| %s }'
    PUT_RECORDS_MAX_COUNT = 1000
    PUT_RECORDS_MAX_DATA_SIZE = 1048576

    Fluent::Plugin.register_output('kinesis',self)

    config_set_default :include_time_key, true
    config_set_default :include_tag_key,  true

    config_param :aws_key_id,  :string, default: nil
    config_param :aws_sec_key, :string, default: nil
    config_param :region,      :string, default: nil

    config_param :stream_name,            :string
    config_param :random_partition_key,   :bool,   default: false
    config_param :partition_key,          :string, default: nil
    config_param :partition_key_expr,     :string, default: nil
    config_param :explicit_hash_key,      :string, default: nil
    config_param :explicit_hash_key_expr, :string, default: nil
    config_param :order_events,           :bool,   default: false

    config_param :debug, :bool, default: false

    def configure(conf)
      super
      validate_params

      if @detach_process or (@num_threads > 1)
        @parallel_mode = true
        if @detach_process
          @use_detach_multi_process_mixin = true
        end
      else
        @parallel_mode = false
      end

      if @parallel_mode
        if @order_events
          log.warn 'You have set "order_events" to true, however this configuration will be ignored due to "detach_process" and/or "num_threads".'
        end
        @order_events = false
      end

      if @partition_key_expr
        partition_key_proc_str = sprintf(
          PROC_BASE_STR, @partition_key_expr
        )
        @partition_key_proc = eval(partition_key_proc_str)
      end

      if @explicit_hash_key_expr
        explicit_hash_key_proc_str = sprintf(
          PROC_BASE_STR, @explicit_hash_key_expr
        )
        @explicit_hash_key_proc = eval(explicit_hash_key_proc_str)
      end
    end

    def start
      detach_multi_process do
        super
        load_client
        check_connection_to_stream
      end
    end

    def format(tag, time, record)
      # XXX: The maximum size of the data blob is 50 kilobytes
      # http://docs.aws.amazon.com/kinesis/latest/APIReference/API_PutRecord.html
      data = {
        data: Base64.strict_encode64(record.to_json),
        partition_key: get_key(:partition_key,record)
      }

      if @explicit_hash_key or @explicit_hash_key_proc
        data[:explicit_hash_key] = get_key(:explicit_hash_key,record)
      end

      data.to_msgpack
    end

    def write(chunk)
      data_list = chunk.to_enum(:msgpack_each).map do |data|
        build_data_to_put(data)
      end

      if @order_events
        put_record_for_order_events(data_list)
      else
        put_records(data_list)
      end
    end

    def put_record_for_order_events(data_list)
      sequence_number_for_ordering = nil
      data_list.each do |data_to_put|
        if sequence_number_for_ordering
          data_to_put.update(
            sequence_number_for_ordering: sequence_number_for_ordering
          )
        end
        data_to_put.update(
          stream_name: @stream_name
        )
        result = @client.put_record(data_to_put)
        sequence_number_for_ordering = result[:sequence_number]
      end
    end

    def put_records(data_list)
      data_list.slice_before([]) {|data_to_put, buf|
        # XXX: Record data size is not strictly...
        data_size = data_to_put.to_s.length
        total_data_size = (buf + [data_size]).inject {|r, i| r + i }

        if buf.length > PUT_RECORDS_MAX_COUNT or total_data_size > PUT_RECORDS_MAX_DATA_SIZE
          buf.clear
          true
        else
          buf << data_size
          false
        end
      }.each {|records|
        @client.put_records(
          records: records,
          stream_name: @stream_name
        )
      }
    end

    private
    def validate_params
      unless @random_partition_key or @partition_key or @partition_key_expr
        raise Fluent::ConfigError, "'random_partition_key' or 'partition_key' or 'partition_key_expr' is required"
      end
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

    def check_connection_to_stream
      @client.describe_stream(stream_name: @stream_name)
    end

    def get_key(name, record)
      if @random_partition_key
        SecureRandom.uuid
      else
        key = instance_variable_get("@#{name}")
        key_proc = instance_variable_get("@#{name}_proc")

        value = key ? record[key] : record

        if key_proc
          value = key_proc.call(value)
        end

        value.to_s
      end
    end

    def build_data_to_put(data)
      Hash[data.map{ |k, v| [k.to_sym, v] }]
    end
  end
end
