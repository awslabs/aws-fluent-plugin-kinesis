#
# Copyright 2014-2026 Amazon Web Services, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License is located at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# or in the "license" file accompanying this file.
# This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and limitations under the License.

require_relative 'aws_emulator_helper'
require 'fluent/plugin/out_kinesis_streams_aggregated'

class KinesisStreamsAggregatedOutputAwsEmulatorTest < Test::Unit::TestCase
  include AwsEmulatorHelper::Kinesis

  def create_driver(conf)
    Fluent::Test::Driver::Output.new(Fluent::Plugin::KinesisStreamsAggregatedOutput).configure(conf)
  end

  # Decode KPL aggregated records into [[user records], partition key in the aggregated record]
  def deaggregate(kinesis_records)
    aggregator = Fluent::Plugin::KinesisHelper::Aggregator.new
    kinesis_records.map do |r|
      assert_true aggregator.aggregated?(r.data)
      records, partition_key = aggregator.deaggregate(r.data)
      assert_equal r.partition_key, partition_key
      [records, partition_key]
    end
  end

  def test_put_aggregated_records_with_default_config
    stream_name = create_stream
    records = (1..3).map { |i| { 'id' => i, 'message' => "hello #{i}" } }
    d = create_driver("stream_name #{stream_name}")
    driver_run(d, records)
    assert_no_error_logs(d)

    actual = read_records(stream_name, 1)
    assert_equal 1, actual.size
    (user_records, partition_key), = deaggregate(actual)
    assert_equal records.map { |r| "#{r.to_json}\n" }, user_records
    assert_match(/\A\h{32}\z/, partition_key)
  end

  def test_put_aggregated_records_with_fixed_partition_key
    stream_name = create_stream(shard_count: 2)
    records = (1..3).map { |i| { 'id' => i } }
    d = create_driver(%[
      stream_name #{stream_name}
      fixed_partition_key fixed-key
      chomp_record true
    ])
    driver_run(d, records)
    assert_no_error_logs(d)

    actual = read_records(stream_name, 1)
    assert_equal [[records.map(&:to_json), 'fixed-key']], deaggregate(actual)
  end

  def test_put_aggregated_records_split_into_multiple_requests
    stream_name = create_stream
    # More than batch_request_max_size of records in a chunk.
    # Keep the total under 1 MB, since a shard accepts up to 1 MB per second and all records go to one shard.
    records = (1..60).map { |i| { 'id' => i, 'data' => 'a' * 10 * 1024 } }
    d = create_driver(%[
      stream_name #{stream_name}
      fixed_partition_key fixed-key
      batch_request_max_size 204800
      <buffer>
        chunk_limit_size 8m
      </buffer>
    ])
    requests = record_requests(d.instance.client, :put_records)
    driver_run(d, records)
    assert_no_error_logs(d)
    assert_operator requests.size, :>=, 3

    actual = read_records(stream_name, requests.size)
    assert_equal requests.size, actual.size
    actual.each { |r| assert_operator r.data.bytesize, :<=, 204800 }
    assert_equal records.map { |r| "#{r.to_json}\n" }, deaggregate(actual).flat_map(&:first)
  end
end
