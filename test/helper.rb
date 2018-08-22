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
def fluentd_v0_12?
  @fluentd_v0_12 ||= Gem.loaded_specs['fluentd'].version < Gem::Version.create('0.14')
end
def aws_sdk_v2?
  @aws_sdk_v2 ||= Gem.loaded_specs['aws-sdk-core'].version < Gem::Version.create('3')
end
def driver_run(d, records, time: nil)
  time ||= event_time("2011-01-02 13:14:15 UTC")
  if fluentd_v0_12?
    records.each{|record| d.emit(record, time)}
    d.run
  else
    d.instance.log.out.flush_logs = false
    d.run(default_tag: "test") do
      records.each{|record| d.feed(time, record)}
    end
  end
end
if !fluentd_v0_12?
  require 'fluent/test/log'
  require 'fluent/test/driver/output'
end
if aws_sdk_v2?
  require 'aws-sdk'
else
  require 'aws-sdk-firehose'
end
require_relative './dummy_server'
require 'test/unit'
require 'mocha/test_unit'
require 'fakefs/safe'
require 'webmock/test_unit'
WebMock.disable!
include Fluent::Test::Helpers

def localize_method(klass, method, &block)
	unbound = klass.instance_method(method)
	klass.send(:define_method, method) do |*args|
		block.call(unbound.bind(self), *args)
	end
	lambda {
		klass.send(:define_method, method, unbound)
	}
end
