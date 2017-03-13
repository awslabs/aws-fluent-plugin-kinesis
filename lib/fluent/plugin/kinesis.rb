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

require 'fluent/plugin/kinesis_helper/client'
require 'fluent/plugin/kinesis_helper/api'
require 'zlib'

module Fluent
  class KinesisOutput < BufferedOutput
    include Fluent::SetTimeKeyMixin
    include Fluent::SetTagKeyMixin

    include KinesisHelper::Client
    include KinesisHelper::API

    class SkipRecordError < ::StandardError; end
    class KeyNotFoundError < SkipRecordError
      def initialize(key, record)
        super "Key '#{key}' doesn't exist on #{record}"
      end
    end
    class ExceedMaxRecordSizeError < SkipRecordError
      def initialize(record)
        super "Record size limit exceeded: #{record.size} B"
      end
    end
    class InvalidRecordError < SkipRecordError
      def initialize(record)
        super "Invalid type of record: #{record}"
      end
    end

    config_param :data_key,              :string,  default: nil
    config_param :log_truncate_max_size, :integer, default: 0
    config_param :compression,           :string,  default: nil
    config_section :format do
      config_set_default :@type, 'json'
    end

    config_param :debug, :bool, default: false

    helpers :formatter

    def configure(conf)
      super
      @data_formatter = data_formatter_create
    end

    def multi_workers_ready?
      true
    end

    private

    def data_formatter_create
      formatter = formatter_create
      compressor = compressor_create
      if @data_key.nil?
        ->(tag, time, record) {
          compressor.call(formatter.format(tag, time, record).chomp)
        }
      else
        ->(tag, time, record) {
          raise InvalidRecordError, record unless record.is_a? Hash
          raise KeyNotFoundError.new(@data_key, record) if record[@data_key].nil?
          compressor.call(record[@data_key].to_s)
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
      if size_of_values(converted) > @max_record_size
        raise ExceedMaxRecordSizeError, converted
      end
      converted.to_msgpack
    rescue SkipRecordError => e
      log.error(truncate e)
      ''
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
