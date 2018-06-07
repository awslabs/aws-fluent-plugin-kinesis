#
# Copyright 2014-2017 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You
# may not use this file except in compliance with the License. A copy of
# the License is located at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# or in the "license" file accompanying this file. This file is
# distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
# ANY KIND, either express or implied. See the License for the specific
# language governing permissions and limitations under the License.

require 'fluent/plugin/kinesis'
require 'json'
require 'aws-sdk-core'

module Fluent
  class KinesisFirehoseOutput < KinesisOutput
    Fluent::Plugin.register_output('kinesis_firehose', self)

    RequestType = :firehose
    BatchRequestLimitCount = 500
    BatchRequestLimitSize  = 4 * 1024 * 1024
    include KinesisHelper::API::BatchRequest

    config_param :delivery_stream_name, :string, :default => nil
    config_param :delivery_stream_name_key, :string, :default => nil
    config_param :delivery_stream_name_suffix, :string, default: ""
    config_param :append_new_line,      :bool, default: true

    def configure(conf)
      super
      unless [conf['delivery_stream_name'], conf['delivery_stream_name_key']].compact.size == 1
        raise Fluent::ConfigError, "Set only one of delivery_stream_name and delivery_stream_name_key"
      end
      if @append_new_line
        org_data_formatter = @data_formatter
        @data_formatter = ->(tag, time, record) {
          org_data_formatter.call(tag, time, record) + "\n"
        }
      end
    end

    def format(tag, time, record)
      format_for_api do
        [@data_formatter.call(tag, time, record)]
      end
    end

    def write(chunk)
      if @delivery_stream_name.nil?
        record_groups = {}
        records = chunk.to_enum(:msgpack_each)
        records.each do |record|
          stream_name = get_stream_name_from_record(record[0])
          if record_groups.has_key?(stream_name)
            record_groups[stream_name].push(record)
          else
            record_groups[stream_name] = [record]
          end
        end
      else
        record_groups = {@delivery_stream_name=>nil}
      end
      record_groups.each do |stream_name, records|
        write_records_batch(chunk, records) do |batch|
          records_to_send = batch.map{|(data)|
            { data: data }
          }
          begin
            client.put_record_batch(
              delivery_stream_name: stream_name,
              records: records_to_send,
            )
          rescue Aws::Firehose::Errors::ResourceNotFoundException => err
            log.error "AWS ResourceNotFoundException - discarding logs because firehose stream does not exist", {
                "error" => err,
                "stream" => stream_name,
            }
            next
          end
        end
      end
    end

    def get_stream_name_from_record(record)
      parsed_record = JSON.parse(record)
      if !parsed_record.key?(@delivery_stream_name_key)
        raise KeyNotFoundError.new(@delivery_stream_name_key, record)
      end
      parsed_record[@delivery_stream_name_key] + @delivery_stream_name_suffix
    end
  end
end
