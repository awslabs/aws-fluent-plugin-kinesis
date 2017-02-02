#
#  Copyright 2014-2017 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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

require 'fluent/plugin/kinesis_helper/class_methods'
require 'fluent/plugin/kinesis_helper/initialize'
require 'fluent/plugin/kinesis_helper/error'

module Fluent
  module KinesisHelper
    include Fluent::SetTimeKeyMixin
    include Fluent::SetTagKeyMixin
    # detach_multi_process has been deleted at 0.14.12
    # https://github.com/fluent/fluentd/commit/fcd8cc18e1f3a95710a80f982b91a1414fadc432
    require 'fluent/version'
    if Gem::Version.new(Fluent::VERSION) < Gem::Version.new('0.14.12')
      require 'fluent/process'
      include Fluent::DetachMultiProcessMixin
    end

    def self.included(klass)
      klass.extend ClassMethods
    end
    include Initialize
  end
end
