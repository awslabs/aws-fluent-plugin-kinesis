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
    class KinesisFirehoseOutput < KinesisOutput
      Fluent::Plugin.register_output('kinesis_firehose', self)

      RequestType = :firehose
      BatchRequestLimitCount = 500
      BatchRequestLimitSize  = 4 * 1024 * 1024
      include KinesisHelper::API::BatchRequest

      config_param :delivery_stream_name, :string
      config_param :append_new_line,      :bool, default: true

      def configure(conf)
        super
        if @append_new_line
          org_data_formatter = @data_formatter
          @data_formatter = ->(tag, time, record) {
            org_data_formatter.call(tag, time, record).chomp + "\n"
          }
        end
      end

      def format(tag, time, record)
        format_for_api do
          [@data_formatter.call(tag, time, record)]
        end
      end

      def write(chunk)
        delivery_stream_name = extract_placeholders(@delivery_stream_name, chunk)
        write_records_batch(chunk) do |batch|
          records = batch.map{|(data)|
            { data: data }
          }
          client.put_record_batch(
            delivery_stream_name: delivery_stream_name,
            records: records,
          )
        end
      end
    end
  end
end
