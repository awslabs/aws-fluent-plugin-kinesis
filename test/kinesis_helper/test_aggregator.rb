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
  AggregateOffset = Fluent::Plugin::KinesisHelper::Aggregator::Mixin::AggregateOffset
  RecordOffset = Fluent::Plugin::KinesisHelper::Aggregator::Mixin::RecordOffset

  def setup
    @aggregator = Fluent::Plugin::KinesisHelper::Aggregator.new
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

  data(
    '1B'    => 1,
    '10B'   => 10,
    '100B'  => 100,
    '256B'  => 256,
    '512B'  => 512,
    '1KB'   => 1024,
    '512KB' => 512*1024,
    '1MB'   => 1024*1024,
  )
  def test_aggregation_offset(data)
    count = data
    record = 'a'*count
    partition_key = 'key'
    encoded1 = @aggregator.aggregate([record], partition_key)
    encoded2 = @aggregator.aggregate([record, record], partition_key)
    assert_equal AggregateOffset, 2*encoded1.size - partition_key.size - encoded2.size
  end

  data(
    '1B'    => 1,
    '10B'   => 10,
    '100B'  => 100,
    '256B'  => 256,
    '512B'  => 512,
    '1KB'   => 1024,
    '512KB' => 512*1024,
    '1MB'   => 1024*1024,
  )
  def test_record_offset(data)
    count = data
    record = 'a'*count
    partition_key = 'key'
    encoded1 = @aggregator.aggregate([record], partition_key)
    encoded2 = @aggregator.aggregate([record,record], partition_key)
    encoded3 = @aggregator.aggregate([record,record,record], partition_key)
    assert_operator RecordOffset, :>=, encoded2.size - encoded1.size - record.size
    assert_operator RecordOffset, :>=, encoded3.size - encoded2.size - record.size
  end

  data(
    '1B'    => 1,
    '10B'   => 10,
    '100B'  => 100,
    '256B'  => 256,
    '512B'  => 512,
    '1KB'   => 1024,
  )
  def test_record_offset_by_records(data)
    count = data
    record = 'a'
    partition_key = 'key'
    encoded1 = @aggregator.aggregate((count-1).times.map{record}, partition_key)
    encoded2 = @aggregator.aggregate(count.times.map{record}, partition_key)
    assert_operator RecordOffset, :>=, encoded2.size - encoded1.size - record.size
  end

  def test_max_size
    size = 1024*1024
    partition_key = 'key'
    record = 'a'*size
    encoded = @aggregator.aggregate([record], partition_key)
    assert_equal size, encoded.size - AggregateOffset - RecordOffset - partition_key.size
  end

  def test_multi_bytes
    count = 1024*1024
    record = 'あ'.b*count
    partition_key = 'key'
    encoded1 = @aggregator.aggregate([record], partition_key)
    encoded2 = @aggregator.aggregate([record, record], partition_key)
    assert_equal AggregateOffset, 2*encoded1.size - partition_key.size - encoded2.size
  end
end
