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

require 'fluent/configurable'
require 'google/protobuf'

Google::Protobuf::DescriptorPool.generated_pool.build do
  add_message "AggregatedRecord" do
    repeated :partition_key_table, :string, 1
    repeated :explicit_hash_key_table, :string, 2
    repeated :records, :message, 3, "Record"
  end
  add_message "Tag" do
    optional :key, :string, 1
    optional :value, :string, 2
  end
  add_message "Record" do
    optional :partition_key_index, :uint64, 1
    optional :explicit_hash_key_index, :uint64, 2
    optional :data, :bytes, 3
    repeated :tags, :message, 4, "Tag"
  end
end

module Fluent
  module Plugin
    module KinesisHelper
      class Aggregator
        AggregatedRecord = Google::Protobuf::DescriptorPool.generated_pool.lookup("AggregatedRecord").msgclass
        Tag = Google::Protobuf::DescriptorPool.generated_pool.lookup("Tag").msgclass
        Record = Google::Protobuf::DescriptorPool.generated_pool.lookup("Record").msgclass

        class InvalidEncodingError < ::StandardError; end

        MagicNumber = ['F3899AC2'].pack('H*')

        def aggregate(records, partition_key)
          message = AggregatedRecord.encode(AggregatedRecord.new(
            partition_key_table: ['a', partition_key],
            records: records.map{|data|
              Record.new(partition_key_index: 1, data: data)
            },
          ))
          [MagicNumber, message, Digest::MD5.digest(message)].pack("A4A*A16")
        end

        def deaggregate(encoded)
          unless aggregated?(encoded)
            raise InvalidEncodingError, "Invalid MagicNumber #{encoded[0..3]}}"
          end
          message, digest = encoded[4..encoded.length-17], encoded[encoded.length-16..-1]
          if Digest::MD5.digest(message) != digest
            raise InvalidEncodingError, "Digest mismatch #{digest}"
          end
          decoded = AggregatedRecord.decode(message)
          records = decoded.records.map(&:data)
          partition_key = decoded.partition_key_table[1]
          [records, partition_key]
        end

        def aggregated?(encoded)
          encoded[0..3] == MagicNumber
        end

        def aggregated_size_offset(partition_key)
          data = 'd'
          encoded = aggregate([record(data)], partition_key)
          finalize(encoded).size - data.size
        end

        module Mixin
          AggregateOffset = 25
          RecordOffset = 10

          module Params
            include Fluent::Configurable
          end

          def self.included(mod)
            mod.include Params
          end

          def aggregator
            @aggregator ||= Aggregator.new
          end
        end
      end
    end
  end
end
