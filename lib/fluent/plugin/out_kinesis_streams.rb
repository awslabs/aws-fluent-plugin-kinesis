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

require 'fluent/plugin/kinesis_helper'

module Fluent
  class KinesisStreamsOutput < BufferedOutput
    include KinesisHelper
    Fluent::Plugin.register_output('kinesis_streams', self)
    config_param_for_streams

    def write(chunk)
      records = convert_to_records(chunk)
      split_to_batches(records).each do |batch|
        batch_request_with_retry(batch)
      end
      log.debug("Written #{records.size} records")
    end

    private

    def convert_format(tag, time, record)
      {
        data: data_format(tag, time, record),
        partition_key: key(record),
      }
    end

    def batch_request(batch)
      client.put_records(
        stream_name: @stream_name,
        records: batch,
      )
    end
  end
end
