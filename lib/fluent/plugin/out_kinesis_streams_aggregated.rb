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
require 'fluent/plugin/kinesis_helper/aggregator'

module Fluent
  class KinesisStreamsAggregatedOutput < KinesisOutput
    Fluent::Plugin.register_output('kinesis_streams_aggregated', self)
    include KinesisHelper::Aggregator::Mixin

    RequestType = :streams_aggregated
    BatchRequestLimitCount = 1 * 1024 * 1024
    BatchRequestLimitSize  = 1024 * 1024
    include KinesisHelper::API::BatchRequest

    config_param :stream_name, :string
    config_param :fixed_partition_key, :string, default: nil

    def configure(conf)
      super
      @batch_request_max_size -= offset
      @max_record_size -= offset
    end

    def format(tag, time, record)
      format_for_api do
        [@data_formatter.call(tag, time, record)]
      end
    end

    def write(chunk)
      write_records_batch(chunk) do |batch|
        key = partition_key
        records = batch.map{|(data)|data}
        client.put_records(
          stream_name: @stream_name,
          records: [{
            partition_key: key,
            data: aggregator.aggregate(records, key),
          }],
        )
      end
    end

    def size_of_values(record)
      super(record) + RecordOffset
    end

    def partition_key
      @fixed_partition_key.nil? ? SecureRandom.hex(16) : @fixed_partition_key
    end

    def offset
      @offset ||= AggregateOffset + partition_key.size*2
    end
  end
end
