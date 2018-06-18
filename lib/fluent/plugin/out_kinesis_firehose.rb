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

module Fluent
  class KinesisFirehoseOutput < KinesisOutput
    Fluent::Plugin.register_output('kinesis_firehose', self)

    RequestType = :firehose
    BatchRequestLimitCount = 500
    BatchRequestLimitSize  = 4 * 1024 * 1024
    include KinesisHelper::API::BatchRequest

    config_param :delivery_stream_name, :string
    config_param :delivery_stream_pool_size, :integer, :default => nil
    config_param :append_new_line,      :bool, default: true

    def configure(conf)
      super
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
      write_records_batch(chunk) do |batch|
        records = batch.map{|(data)|
          { data: data }
        }
        unless delivery_stream_pool_size.nil?
          random_stream_number = rand(0..delivery_stream_pool_size-1)
          delivery_stream_name_in_use = @delivery_stream_name + "-" + random_stream_number.to_s
        else
          delivery_stream_name_in_use = @delivery_stream_name
        end
        begin
          puts "stream name " + delivery_stream_name_in_use
          client.put_record_batch(
            delivery_stream_name: delivery_stream_name_in_use,
            records: records,
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
end
