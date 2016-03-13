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

module Fluent
  module KinesisHelper
    module Format
      MAX_RECORD_SIZE = 1024 * 1024 # 1 MB

      def configure(conf)
        super
        @formatter = Fluent::Plugin.new_formatter(@formatter)
        @formatter.configure(conf)
      end

      def format(tag, time, record)
        [tag, time, record].to_msgpack
      end

      private

      def data_format(tag, time, record)
        data = @formatter.format(tag, time, record)
        data += "\n" if @append_new_line
        data
      end

      def key(record)
        if @partition_key.nil?
          SecureRandom.hex(16)
        elsif !record.key?(@partition_key)
          raise Fluent::KinesisHelper::KeyNotFoundError.new(@partition_key, record)
        else
          record[@partition_key]
        end
      end

      def convert_to_records(chunk)
        chunk.to_enum(:msgpack_each).map{|tag, time, record|
          convert_record(tag, time, record)
        }.compact
      end

      def convert_record(tag, time, record)
        unless record.is_a? Hash
          raise Fluent::KinesisHelper::InvalidRecordError, record
        end
        converted = convert_format(tag, time, record)
        if converted[:data].size > MAX_RECORD_SIZE
          raise Fluent::KinesisHelper::ExceedMaxRecordSizeError, converted[:data]
        else
          converted
        end
      rescue => e
        log.error(e)
        nil
      end
    end
  end
end
