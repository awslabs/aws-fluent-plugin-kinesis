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
require 'fluent/plugin/out_kinesis_streams'

class KinesisStreamsOutputAwsEmulatorTest < Test::Unit::TestCase
  include AwsEmulatorHelper::Kinesis

  def create_driver(conf)
    Fluent::Test::Driver::Output.new(Fluent::Plugin::KinesisStreamsOutput).configure(conf)
  end

  def test_put_records_with_default_config
    stream_name = create_stream
    records = (1..3).map { |i| { 'id' => i, 'message' => "hello #{i}" } }
    d = create_driver("stream_name #{stream_name}")
    driver_run(d, records)
    assert_no_error_logs(d)

    actual = read_records(stream_name, records.size)
    assert_equal records.map { |r| "#{r.to_json}\n" }, actual.map(&:data)
    actual.each { |r| assert_match(/\A\h{32}\z/, r.partition_key) }
    assert_equal records.size, actual.map(&:partition_key).uniq.size
  end

  def test_put_records_with_partition_key_and_chomp_record
    stream_name = create_stream(shard_count: 2)
    records = %w[a b c a].map.with_index { |key, i| { 'key' => key, 'id' => i } }
    d = create_driver(%[
      stream_name #{stream_name}
      partition_key key
      chomp_record true
    ])
    driver_run(d, records)
    assert_no_error_logs(d)

    actual = read_records(stream_name, records.size)
    assert_equal records.map { |r| [r.to_json, r['key']] }.sort,
                 actual.map { |r| [r.data, r.partition_key] }.sort
  end

  def test_put_records_with_data_key_and_compression
    stream_name = create_stream
    records = (1..3).map { |i| { 'data' => "raw data #{i}", 'other' => i } }
    d = create_driver(%[
      stream_name #{stream_name}
      data_key data
      compression zlib
    ])
    driver_run(d, records)
    assert_no_error_logs(d)

    actual = read_records(stream_name, records.size)
    assert_equal records.map { |r| r['data'] }, actual.map { |r| Zlib::Inflate.inflate(r.data) }
  end

  def test_put_records_with_inject_and_ltsv_format
    stream_name = create_stream
    time = event_time('2011-01-02 13:14:15 UTC')
    d = create_driver(%[
      stream_name #{stream_name}
      <inject>
        tag_key tag
        time_key time
        utc true
      </inject>
      <format>
        @type ltsv
      </format>
    ])
    driver_run(d, [{ 'a' => 1 }], time: time)
    assert_no_error_logs(d)

    actual = read_records(stream_name, 1)
    assert_equal ["a:1\ttag:test\ttime:2011-01-02T13:14:15.000000000+0000\n"], actual.map(&:data)
  end

  def test_put_records_split_into_multiple_requests
    # Use 2 shards, since a shard accepts up to 1,000 records per second
    stream_name = create_stream(shard_count: 2)
    # More than BatchRequestLimitCount (500) records in a chunk
    records = (1..1200).map { |i| { 'id' => i } }
    d = create_driver("stream_name #{stream_name}")
    requests = record_requests(d.instance.client, :put_records)
    driver_run(d, records)
    assert_no_error_logs(d)
    assert_equal 3, requests.size

    # Records are ordered only within each shard
    actual = read_records(stream_name, records.size)
    assert_equal records.map { |r| "#{r.to_json}\n" }.sort, actual.map(&:data).sort
  end
end
