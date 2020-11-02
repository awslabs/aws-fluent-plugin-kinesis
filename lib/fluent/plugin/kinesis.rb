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

require 'fluent/version'
require 'fluent/msgpack_factory'
require 'fluent/plugin/output'
require 'fluent/plugin/kinesis_helper/client'
require 'fluent/plugin/kinesis_helper/api'
require 'zlib'

module Fluent
  module Plugin
    class KinesisOutput < Fluent::Plugin::Output
      include KinesisHelper::Client
      include KinesisHelper::API

      class SkipRecordError < ::StandardError
        def initialize(message, record)
          super message
          @record_message = if record.is_a? Array
                              record.reverse.map(&:to_s).join(', ')
                            else
                              record.to_s
                            end
        end

        def to_s
          super + ": " + @record_message
        end
      end
      class KeyNotFoundError < SkipRecordError
        def initialize(key, record)
          super "Key '#{key}' doesn't exist", record
        end
      end
      class ExceedMaxRecordSizeError < SkipRecordError
        def initialize(size, record)
          super "Record size limit exceeded in #{size/1024} KB", record
        end
      end
      class InvalidRecordError < SkipRecordError
        def initialize(record)
          super "Invalid type of record", record
        end
      end

      config_param :data_key,              :string,  default: nil
      config_param :log_truncate_max_size, :integer, default: 1024
      config_param :compression,           :string,  default: nil

      desc "Formatter calls chomp and removes separator from the end of each record. This option is for compatible format with plugin v2. (default: false)"
      # https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/142
      config_param :chomp_record,          :bool,    default: false

      config_section :format do
        config_set_default :@type, 'json'
      end
      config_section :inject do
        config_set_default :time_type, 'string'
        config_set_default :time_format, '%Y-%m-%dT%H:%M:%S.%N%z'
      end

      config_param :debug, :bool, default: false

      helpers :formatter, :inject

      def configure(conf)
        super
        @data_formatter = data_formatter_create(conf)
      end

      def multi_workers_ready?
        true
      end

      def formatted_to_msgpack_binary?
        true
      end

      private

      def data_formatter_create(conf)
        formatter = formatter_create
        compressor = compressor_create
        if @data_key.nil?
          if @chomp_record
            ->(tag, time, record) {
              record = inject_values_to_record(tag, time, record)
              # Formatter calls chomp and removes separator from the end of each record.
              # This option is for compatible format with plugin v2.
              # https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/142
              compressor.call(formatter.format(tag, time, record).chomp.b)
            }
          else
            ->(tag, time, record) {
              record = inject_values_to_record(tag, time, record)
              compressor.call(formatter.format(tag, time, record).b)
            }
          end
        else
          ->(tag, time, record) {
            raise InvalidRecordError, record unless record.is_a? Hash
            raise KeyNotFoundError.new(@data_key, record) if record[@data_key].nil?
            compressor.call(record[@data_key].to_s.b)
          }
        end
      end

      def compressor_create
        case @compression
        when "zlib"
          ->(data) { Zlib::Deflate.deflate(data) }
        else
          ->(data) { data }
        end
      end

      def format_for_api(&block)
        converted = block.call
        size = size_of_values(converted)
        if size > @max_record_size
          raise ExceedMaxRecordSizeError.new(size, converted)
        end
        converted.to_msgpack
      rescue SkipRecordError => e
        log.error(truncate e)
        ''
      end

      if Gem::Version.new(Fluent::VERSION) >= Gem::Version.new('1.8.0')
        def msgpack_unpacker(*args)
          Fluent::MessagePackFactory.msgpack_unpacker(*args)
        end
      else
        include Fluent::MessagePackFactory::Mixin
      end

      def write_records_batch(chunk, &block)
        unique_id = chunk.dump_unique_id_hex(chunk.unique_id)
        records = chunk.to_enum(:msgpack_each)
        split_to_batches(records) do |batch, size|
          log.debug(sprintf "Write chunk %s / %3d records / %4d KB", unique_id, batch.size, size/1024)
          batch_request_with_retry(batch, &block)
          log.debug("Finish writing chunk")
        end
      end

      def request_type
        self.class::RequestType
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
