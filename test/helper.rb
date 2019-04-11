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

require 'aws-sdk-core'
require 'fluent/test'
require 'fluent/test/helpers'
def driver_run(d, records, time: nil)
  time ||= event_time("2011-01-02 13:14:15 UTC")
  d.instance.log.out.flush_logs = false
  d.run(default_tag: "test") do
    records.each{|record| d.feed(time, record)}
  end
end
require 'fluent/test/log'
require 'fluent/test/driver/output'
require 'aws-sdk-firehose'
require_relative './dummy_server'
require 'test/unit'
require 'mocha/test_unit'
require 'fakefs/safe'
require 'webmock/test_unit'
WebMock.disable!
include Fluent::Test::Helpers
