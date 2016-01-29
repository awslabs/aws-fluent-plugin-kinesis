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

##
# This file is auto-generated. DO NOT EDIT!
#
require 'protobuf/message'


##
# Imports
#
require 'kinesis_producer/protobuf/config.pb'

module KinesisProducer
  module Protobuf

    ##
    # Message Classes
    #
    class Tag < ::Protobuf::Message; end
    class Record < ::Protobuf::Message; end
    class AggregatedRecord < ::Protobuf::Message; end
    class Message < ::Protobuf::Message; end
    class PutRecord < ::Protobuf::Message; end
    class Flush < ::Protobuf::Message; end
    class Attempt < ::Protobuf::Message; end
    class PutRecordResult < ::Protobuf::Message; end
    class Credentials < ::Protobuf::Message; end
    class SetCredentials < ::Protobuf::Message; end
    class Dimension < ::Protobuf::Message; end
    class Stats < ::Protobuf::Message; end
    class Metric < ::Protobuf::Message; end
    class MetricsRequest < ::Protobuf::Message; end
    class MetricsResponse < ::Protobuf::Message; end


    ##
    # Message Fields
    #
    class Tag
      required :string, :key, 1
      optional :string, :value, 2
    end

    class Record
      required :uint64, :partition_key_index, 1
      optional :uint64, :explicit_hash_key_index, 2
      required :bytes, :data, 3
      repeated ::KinesisProducer::Protobuf::Tag, :tags, 4
    end

    class AggregatedRecord
      repeated :string, :partition_key_table, 1
      repeated :string, :explicit_hash_key_table, 2
      repeated ::KinesisProducer::Protobuf::Record, :records, 3
    end

    class Message
      required :uint64, :id, 1
      optional :uint64, :source_id, 2
      optional ::KinesisProducer::Protobuf::PutRecord, :put_record, 3
      optional ::KinesisProducer::Protobuf::Flush, :flush, 4
      optional ::KinesisProducer::Protobuf::PutRecordResult, :put_record_result, 5
      optional ::KinesisProducer::Protobuf::Configuration, :configuration, 6
      optional ::KinesisProducer::Protobuf::MetricsRequest, :metrics_request, 7
      optional ::KinesisProducer::Protobuf::MetricsResponse, :metrics_response, 8
      optional ::KinesisProducer::Protobuf::SetCredentials, :set_credentials, 9
    end

    class PutRecord
      required :string, :stream_name, 1
      required :string, :partition_key, 2
      optional :string, :explicit_hash_key, 3
      required :bytes, :data, 4
    end

    class Flush
      optional :string, :stream_name, 1
    end

    class Attempt
      required :uint32, :delay, 1
      required :uint32, :duration, 2
      required :bool, :success, 3
      optional :string, :error_code, 4
      optional :string, :error_message, 5
    end

    class PutRecordResult
      repeated ::KinesisProducer::Protobuf::Attempt, :attempts, 1
      required :bool, :success, 2
      optional :string, :shard_id, 3
      optional :string, :sequence_number, 4
    end

    class Credentials
      required :string, :akid, 1
      required :string, :secret_key, 2
      optional :string, :token, 3
    end

    class SetCredentials
      optional :bool, :for_metrics, 1
      required ::KinesisProducer::Protobuf::Credentials, :credentials, 2
    end

    class Dimension
      required :string, :key, 1
      required :string, :value, 2
    end

    class Stats
      required :double, :count, 1
      required :double, :sum, 2
      required :double, :mean, 3
      required :double, :min, 4
      required :double, :max, 5
    end

    class Metric
      required :string, :name, 1
      repeated ::KinesisProducer::Protobuf::Dimension, :dimensions, 2
      required ::KinesisProducer::Protobuf::Stats, :stats, 3
      required :uint64, :seconds, 4
    end

    class MetricsRequest
      optional :string, :name, 1
      optional :uint64, :seconds, 2
    end

    class MetricsResponse
      repeated ::KinesisProducer::Protobuf::Metric, :metrics, 1
    end

  end

end

