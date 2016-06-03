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
  class KinesisProducerOutput < BufferedOutput
    include KinesisHelper
    Fluent::Plugin.register_output('kinesis_producer', self)
    config_param_for_producer

    def configure(conf)
      super
      unless @stream_name or @stream_name_prefix
        raise Fluent::ConfigError, "'stream_name' or 'stream_name_prefix' is required"
      end
      if @stream_name and @stream_name_prefix
        raise Fluent::ConfigError, "Only one of 'stream_name' or 'stream_name_prefix' is allowed"
      end
    end

    def write(chunk)
      records = convert_to_records(chunk)
      wait_futures(write_chunk_to_kpl(records))
    end

    private

    def convert_format(tag, time, record)
      {
        data: data_format(tag, time, record),
        partition_key: key(record),
        stream_name: @stream_name ? @stream_name : @stream_name_prefix + tag,
      }
    end
  end
end
