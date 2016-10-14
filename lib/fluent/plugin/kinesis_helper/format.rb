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

require 'fluent/plugin/kinesis_helper/error'

module Fluent
  module KinesisHelper
    module Format
      MaxRecordSize = 1024 * 1024 # 1 MB

      def configure(conf)
        super
        @formatter = Fluent::Plugin.new_formatter(@formatter)
        @formatter.configure(conf)
      end

      def format(tag, time, record)
        Fluent::Engine.msgpack_factory.packer.write([tag, time, record]).to_s
      end

      private

      def data_format(tag, time, record)
        if @data_key and record[@data_key].nil?
          raise KeyNotFoundError.new(@data_key, record)
        elsif @data_key
          record[@data_key].to_s
        else
          @formatter.format(tag, time, record).chomp
        end
      end

      def key(record)
        if @partition_key.nil?
          SecureRandom.hex(16)
        elsif !record.key?(@partition_key)
          raise KeyNotFoundError.new(@partition_key, record)
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
          raise InvalidRecordError, record
        end
        converted = convert_format(tag, time, record)
        converted[:data] += "\n" if @append_new_line
        if converted[:data].size > MaxRecordSize
          raise ExceedMaxRecordSizeError, converted[:data]
        else
          converted
        end
      rescue SkipRecordError => e
        log.error(truncate e)
        nil
      end

      def truncate(msg)
        if @log_truncate_max_size == 0 or (msg.to_s.size <= @log_truncate_max_size)
          msg.to_s
        else
          msg.to_s[0...@log_truncate_max_size]
        end
      end
    end
  end
end
