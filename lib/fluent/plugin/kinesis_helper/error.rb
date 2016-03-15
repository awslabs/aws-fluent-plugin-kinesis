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
    class BaseError < ::StandardError; end
    class SkipRecordError < BaseError; end

    class KeyNotFoundError < SkipRecordError
      def initialize(key, record)
        super "Key '#{key}' doesn't exist on #{record}"
      end
    end

    class ExceedMaxRecordSizeError < SkipRecordError
      def initialize(record)
        super "Record size limit exceeded for #{record}"
      end
    end

    class InvalidRecordError < SkipRecordError
      def initialize(record)
        super "Invalid type of record: #{record}"
      end
    end
  end
end
