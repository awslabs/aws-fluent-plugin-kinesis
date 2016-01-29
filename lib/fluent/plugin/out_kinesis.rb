#
#  Copyright 2014-2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
#  Licensed under the Amazon Software License (the "License").
#  You may not use this file except in compliance with the License.
#  A copy of the License is located at
#
#  http://aws.amazon.com/asl/
#
#  or in the "license" file accompanying this file. This file is distributed
#  on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
#  express or implied. See the License for the specific language governing
#  permissions and limitations under the License.

require 'aws-sdk'
require 'yajl'
require 'logger'
require 'securerandom'
require 'zlib'
require 'fluent_plugin_kinesis/version'

module FluentPluginKinesis
  class OutputFilter < Fluent::BufferedOutput

    include Fluent::DetachMultiProcessMixin
    include Fluent::SetTimeKeyMixin
    include Fluent::SetTagKeyMixin

    USER_AGENT_NAME = 'fluent-plugin-kinesis-output-filter'
    PROC_BASE_STR = 'proc {|record| %s }'
    PUT_RECORDS_MAX_COUNT = 500
    PUT_RECORD_MAX_DATA_SIZE = 1024 * 1024
    PUT_RECORDS_MAX_DATA_SIZE = 1024 * 1024 * 5

    Fluent::Plugin.register_output('kinesis',self)

    config_set_default :include_time_key, true
    config_set_default :include_tag_key,  true

    config_param :aws_key_id,  :string, default: nil, :secret => true
    config_param :aws_sec_key, :string, default: nil, :secret => true
    # The 'region' parameter is optional because
    # it may be set as an environment variable.
    config_param :region,      :string, default: nil
    config_param :ensure_stream_connection, :bool, default: true

    config_param :profile,          :string, :default => nil
    config_param :credentials_path, :string, :default => nil
    config_param :role_arn,         :string, :default => nil
    config_param :external_id,      :string, :default => nil

    config_param :stream_name,            :string
    config_param :random_partition_key,   :bool,   default: false
    config_param :partition_key,          :string, default: nil
    config_param :partition_key_expr,     :string, default: nil
    config_param :explicit_hash_key,      :string, default: nil
    config_param :explicit_hash_key_expr, :string, default: nil
    config_param :order_events,           :bool,   default: false
    config_param :retries_on_putrecords,  :integer, default: 3
    config_param :use_yajl,               :bool,   default: false
    config_param :zlib_compression,       :bool,   default: false

    config_param :debug, :bool, default: false

    config_param :http_proxy, :string, default: nil

    def configure(conf)
      log.warn("Deprecated warning: out_kinesis is no longer supported after v1.0.0. Please check out_kinesis_streams out.")
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

      @dump_class = @use_yajl ? Yajl : JSON
    end

    def start
      detach_multi_process do
        super
        load_client
        if @ensure_stream_connection
          check_connection_to_stream
        end
      end
    end

    def format(tag, time, record)
      data = {
        data: @dump_class.dump(record),
        partition_key: get_key(:partition_key,record)
      }

      if @explicit_hash_key or @explicit_hash_key_proc
        data[:explicit_hash_key] = get_key(:explicit_hash_key,record)
      end

      data.to_msgpack
    end

    def write(chunk)
      data_list = chunk.to_enum(:msgpack_each).map{|record|
        build_data_to_put(record)
      }.find_all{|record|
        unless record_exceeds_max_size?(record[:data])
          true
        else
          log.error sprintf('Record exceeds the %.3f KB(s) per-record size limit and will not be delivered: %s', PUT_RECORD_MAX_DATA_SIZE / 1024.0, record[:data])
          false
        end
      }

      if @order_events
        put_record_for_order_events(data_list)
      else
        records_array = build_records_array_to_put(data_list)
        records_array.each{|records|
          put_records_with_retry(records)
        }
      end
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
      elsif @profile
        credentials_opts = {:profile_name => @profile}
        credentials_opts[:path] = @credentials_path if @credentials_path
        credentials = Aws::SharedCredentials.new(credentials_opts)
        options[:credentials] = credentials
      elsif @role_arn
        credentials = Aws::AssumeRoleCredentials.new(
          client: Aws::STS::Client.new(options),
          role_arn: @role_arn,
          role_session_name: "aws-fluent-plugin-kinesis",
          external_id: @external_id,
          duration_seconds: 60 * 60
        )
        options[:credentials] = credentials
      end

      if @debug
        options.update(
          logger: Logger.new(log.out),
          log_level: :debug
        )
        # XXX: Add the following options, if necessary
        # :http_wire_trace => true
      end

      if @http_proxy
        options[:http_proxy] = @http_proxy
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
      if @zlib_compression
        Hash[data.map{|k, v| [k.to_sym, k=="data" ? Zlib::Deflate.deflate(v) : v] }]
      else
        Hash[data.map{|k, v| [k.to_sym, v] }]
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

    def build_records_array_to_put(data_list)
      records_array = []
      records = []
      records_payload_length = 0
      data_list.each{|data_to_put|
        payload = data_to_put[:data]
        partition_key = data_to_put[:partition_key]
        if records.length >= PUT_RECORDS_MAX_COUNT or (records_payload_length + payload.length + partition_key.length) >= PUT_RECORDS_MAX_DATA_SIZE
          records_array.push(records)
          records = []
          records_payload_length = 0
        end
        records.push(data_to_put)
        records_payload_length += (payload.length + partition_key.length)
      }
      records_array.push(records) unless records.empty?
      records_array
    end

    def put_records_with_retry(records,retry_count=0)
      response = @client.put_records(
        records: records,
        stream_name: @stream_name
      )

      if response[:failed_record_count] && response[:failed_record_count] > 0
        failed_records = []
        response[:records].each_with_index{|record,index|
          if record[:error_code]
            failed_records.push({body: records[index], error_code: record[:error_code]})
          end
        }

        if(retry_count < @retries_on_putrecords)
          sleep(calculate_sleep_duration(retry_count))
          retry_count += 1
          log.warn sprintf('Retrying to put records. Retry count: %d', retry_count)
          put_records_with_retry(
            failed_records.map{|record| record[:body]},
            retry_count
          )
        else
          failed_records.each{|record|
            log.error sprintf(
              'Could not put record, Error: %s, Record: %s',
              record[:error_code],
              @dump_class.dump(record[:body])
            )
          }
        end
      end
    end

    def calculate_sleep_duration(current_retry)
      Array.new(@retries_on_putrecords){|n| ((2 ** n) * scaling_factor)}[current_retry]
    end

    def scaling_factor
      0.5 + Kernel.rand * 0.1
    end

    def record_exceeds_max_size?(record_string)
      return record_string.length > PUT_RECORD_MAX_DATA_SIZE
    end
  end
end
