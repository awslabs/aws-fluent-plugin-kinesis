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
    module Initialize
      def initialize
        super
        class << self
          define_method('log') { $log } unless method_defined?(:log)

          require 'aws-sdk'
          require 'fluent/plugin/kinesis_helper/format'
          require 'fluent/plugin/kinesis_helper/client'
          require 'fluent/plugin/kinesis_helper/credentials'
          include Format, Client, Credentials

          case
          when api?
            require 'fluent/plugin/kinesis_helper/api'
            include API
          when kpl?
            require 'fluent/plugin/kinesis_helper/kpl'
            require 'fluent/version'
            if Gem::Version.new(Fluent::VERSION) < Gem::Version.new('0.12.20')
              # Backport from https://github.com/fluent/fluentd/pull/757
              require 'fluent/plugin/patched_detach_process_impl'
              include PatchedDetachProcessImpl
            end
            include KPL
          end

          def request_type
            self.class.request_type
          end

          def api?
            self.class.api?
          end

          def kpl?
            self.class.kpl?
          end
        end
      end
    end
  end
end
