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
    class BaseError < ::StandardError
      TruncateSize = 200
      attr_reader :truncated

      def initialize(msg=nil)
        super
        @truncated = (msg.is_a? String and msg.size > TruncateSize) ? msg[0...TruncateSize] + '...' : msg
      end

      def to_s
        truncated || super
      end
    end

    class KeyNotFoundError < BaseError
      def initialize(key, record)
        msg = "Key '#{key}' doesn't exist on #{record}"
        super(msg)
      end
    end

    class ExceedMaxRecordSizeError < BaseError
      def to_s
        "Record size limit exceeded for #{truncated}"
      end
    end

    class InvalidRecordError < BaseError
      def initialize(record)
        msg = "Invalid type of record: #{record}"
        super(msg)
      end
    end
  end
end
