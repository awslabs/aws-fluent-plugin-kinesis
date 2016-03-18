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

module KinesisProducer
  module Protobuf
    ##
    # Message Classes
    #
    class AdditionalDimension < ::Protobuf::Message; end
    class Configuration < ::Protobuf::Message; end


    ##
    # Message Fields
    #
    class AdditionalDimension
      required :string, :key, 1
      required :string, :value, 2
      required :string, :granularity, 3
    end

    class Configuration
      repeated ::KinesisProducer::Protobuf::AdditionalDimension, :additional_metric_dims, 128
      optional :bool, :aggregation_enabled, 1, :default => true
      optional :uint64, :aggregation_max_count, 2, :default => 4294967295
      optional :uint64, :aggregation_max_size, 3, :default => 51200
      optional :uint64, :collection_max_count, 4, :default => 500
      optional :uint64, :collection_max_size, 5, :default => 5242880
      optional :uint64, :connect_timeout, 6, :default => 6000
      optional :string, :custom_endpoint, 7
      optional :bool, :fail_if_throttled, 8, :default => false
      optional :string, :log_level, 9, :default => "info"
      optional :uint64, :max_connections, 10, :default => 24
      optional :string, :metrics_granularity, 11, :default => "shard"
      optional :string, :metrics_level, 12, :default => "detailed"
      optional :string, :metrics_namespace, 13, :default => "KinesisProducerLibrary"
      optional :uint64, :metrics_upload_delay, 14, :default => 60000
      optional :uint64, :min_connections, 15, :default => 1
      optional :uint64, :port, 16, :default => 443
      optional :uint64, :rate_limit, 17, :default => 150
      optional :uint64, :record_max_buffered_time, 18, :default => 100
      optional :uint64, :record_ttl, 19, :default => 30000
      optional :string, :region, 20
      optional :uint64, :request_timeout, 21, :default => 6000
      optional :bool, :verify_certificate, 22, :default => true
    end

  end
end

