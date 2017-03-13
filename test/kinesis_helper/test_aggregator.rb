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

require_relative '../helper'
require 'fluent/plugin/kinesis_helper/aggregator'

class KinesisHelperAggregatorTest < Test::Unit::TestCase
  def setup
    @aggregator = Fluent::KinesisHelper::Aggregator.new
  end

  def teardown
  end

  def test_aggregate
    records = ['foo', 'bar']
    partition_key = 'key'
    encoded = @aggregator.aggregate(records, partition_key)
    decoded = @aggregator.deaggregate(encoded)
    assert_equal records, decoded[0]
    assert_equal partition_key, decoded[1]
  end
end
