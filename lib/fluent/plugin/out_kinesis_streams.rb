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
  module Plugin
    class KinesisStreamsOutput < KinesisOutput
      Fluent::Plugin.register_output('kinesis_streams', self)

      RequestType = :streams
      BatchRequestLimitCount = 500
      BatchRequestLimitSize  = 5 * 1024 * 1024
      include KinesisHelper::API::BatchRequest

      config_param :stream_name,   :string
      config_param :partition_key, :string,  default: nil

      def configure(conf)
        super
        @key_formatter = key_formatter_create
      end

      def format(tag, time, record)
        format_for_api do
          data = @data_formatter.call(tag, time, record)
          key = @key_formatter.call(record)
          [data, key]
        end
      end

      def write(chunk)
        stream_name = extract_placeholders(@stream_name, chunk)
        write_records_batch(chunk) do |batch|
          records = batch.map{|(data, partition_key)|
            { data: data, partition_key: partition_key }
          }
          client.put_records(
            stream_name: stream_name,
            records: records,
          )
        end
      end

      private

      def key_formatter_create
        if @partition_key.nil?
          ->(record) { SecureRandom.hex(16) }
        else
          ->(record) {
            if !record.key?(@partition_key)
              raise KeyNotFoundError.new(@partition_key, record)
            end
            record[@partition_key]
          }
        end
      end
    end
  end
end
