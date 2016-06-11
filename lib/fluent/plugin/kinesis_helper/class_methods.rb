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
    module ClassMethods
      def config_param_for_streams
        const_set(:RequestType, :streams)
        const_set(:BatchRequestLimitCount, 500)
        const_set(:BatchRequestLimitSize, 5 * 1024 * 1024)
        config_param :stream_name,   :string
        config_param :region,        :string,  default: nil
        config_param :partition_key, :string,  default: nil
        config_param_for_sdk
        config_param_for_credentials
        config_param_for_format
        config_param_for_batch_request
        config_param_for_debug
      end

      def config_param_for_firehose
        const_set(:RequestType, :firehose)
        const_set(:BatchRequestLimitCount, 500)
        const_set(:BatchRequestLimitSize, 4 * 1024 * 1024)
        config_param :delivery_stream_name, :string
        config_param :region,               :string,  default: nil
        config_param :append_new_line,      :bool,    default: true
        config_param_for_sdk
        config_param_for_credentials
        config_param_for_format
        config_param_for_batch_request
        config_param_for_debug
      end

      def config_param_for_producer
        const_set(:RequestType, :producer)
        config_param :stream_name,        :string, default: nil
        config_param :stream_name_prefix, :string, default: nil
        config_param :region,             :string, default: nil
        config_param :partition_key,      :string, default: nil
        config_param_for_credentials
        config_param_for_format
        config_param_for_debug

        config_section :kinesis_producer, multi: false do
          require 'kinesis_producer'
          type_map = {
            Protobuf::Field::BoolField   => :bool,
            Protobuf::Field::Uint64Field => :integer,
            Protobuf::Field::StringField => :string,
          }
          KinesisProducer::ConfigurationFields.each do |field|
            next if field.name == 'region'
            type = type_map[field.type_class]
            config_param field.name, type, default: field.default_value
          end
          config_param :credentials_refresh_delay, :integer, default: 5000
        end
      end

      def config_param_for_sdk
        config_param :http_proxy,      :string, default: nil, secret: true
        config_param :endpoint,        :string, default: nil
        config_param :ssl_verify_peer, :bool,   default: true
      end

      def config_param_for_credentials
        config_param :aws_key_id,  :string, default: nil, secret: true
        config_param :aws_sec_key, :string, default: nil, secret: true
        config_section :shared_credentials, multi: false do
          config_param :profile_name, :string, default: nil
          config_param :path,         :string, default: nil
        end
        config_section :assume_role_credentials, multi: false do
          config_param :role_arn,    :string,               secret: true
          config_param :external_id, :string, default: nil, secret: true
        end
      end

      def config_param_for_format
        config_param :formatter,             :string,  default: 'json'
        config_param :data_key,              :string,  default: nil
        config_param :log_truncate_max_size, :integer, default: 0
      end

      def config_param_for_batch_request
        config_param :retries_on_batch_request, :integer, default: 3
        config_param :reset_backoff_if_success, :bool,    default: true
        config_param :batch_request_max_count,  :integer, default: const_get(:BatchRequestLimitCount)
        config_param :batch_request_max_size,   :integer, default: const_get(:BatchRequestLimitSize)
      end

      def config_param_for_debug
        config_param :debug, :bool, default: false
      end

      def request_type
        const_get(:RequestType)
      end

      def api?
        [:streams, :firehose].include?(request_type)
      end

      def kpl?
        [:producer].include?(request_type)
      end
    end
  end
end
