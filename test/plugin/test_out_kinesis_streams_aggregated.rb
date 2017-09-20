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
require 'fluent/plugin/out_kinesis_streams_aggregated'

class KinesisStreamsOutputAggregatedTest < Test::Unit::TestCase
  KB = 1024
  MB = 1024 * KB
  AggregateOffset = 25
  RecordOffset = 7

  def setup
    ENV['AWS_REGION'] = 'ap-northeast-1'
    ENV['AWS_ACCESS_KEY_ID'] = 'AAAAAAAAAAAAAAAAAAAA'
    ENV['AWS_SECRET_ACCESS_KEY'] = 'ffffffffffffffffffffffffffffffffffffffff'
    Fluent::Test.setup
    @server = DummyServer.start
  end

  def teardown
    ENV.delete('AWS_REGION')
    ENV.delete('AWS_ACCESS_KEY_ID')
    ENV.delete('AWS_SECRET_ACCESS_KEY')
    @server.clear
  end

  def default_config
    %[
      stream_name test-stream
      log_level error

      endpoint https://localhost:#{@server.port}
      ssl_verify_peer false
    ]
  end

  def create_driver(conf = default_config)
    Fluent::Test::Driver::Output.new(Fluent::KinesisStreamsAggregatedOutput) do
    end.configure(conf)
  end

  def self.data_of(size)
    offset_size = RecordOffset
    'a' * (size - offset_size)
  end

  def data_of(size)
    self.class.data_of(size)
  end

  def test_configure
    d = create_driver
    assert_equal 'test-stream', d.instance.stream_name
    assert_equal 'ap-northeast-1' , d.instance.region
  end

  def test_region
    d = create_driver(default_config + "region us-east-1")
    assert_equal 'us-east-1', d.instance.region
  end

  data(
    'json' => ['json', '{"a":1,"b":2}'],
    'ltsv' => ['ltsv', "a:1\tb:2"],
  )
  def test_format(data)
    formatter, expected = data
    d = create_driver(default_config + "format #{formatter}")
    d.instance.log.out.flush_logs = false
    time = event_time("2011-01-02 13:14:15 UTC")
    d.run(default_tag: "test") do
      d.feed(time, {"a"=>1,"b"=>2})
    end
    assert_equal expected, @server.records.first
  end

  def test_data_key
    d = create_driver(default_config + "data_key a")
    d.instance.log.out.flush_logs = false
    time = event_time("2011-01-02 13:14:15 UTC")
    d.run(default_tag: "test") do
      d.feed(time, {"a"=>1,"b"=>2})
      d.feed(time, {"b"=>2})
    end
    assert_equal "1", @server.records.first
    assert_equal 1, @server.records.size
    assert_equal 1, d.instance.log.out.logs.size
  end

  data(
    'random' => [nil, AggregateOffset+32*2],
    'fixed'  => ['k', AggregateOffset+1*2],
  )
  def test_max_data_size(data)
    fixed, expected = data
    config = 'data_key a'
    config += "\nfixed_partition_key #{fixed}" unless fixed.nil?
    d = create_driver(default_config + config)
    d.instance.log.out.flush_logs = false
    offset = d.instance.offset
    assert_equal expected, offset
    time = event_time("2011-01-02 13:14:15 UTC")
    d.run(default_tag: "test") do
      d.feed(time, {"a"=>data_of(1*MB-offset)})
      d.feed(time, {"a"=>data_of(1*MB-offset+1)}) # exceeded
    end
    assert_equal 1, d.instance.log.out.logs.size
    assert_equal 1, @server.records.size
  end

  data(
    'random' => [nil, AggregateOffset+32*2],
    'fixed'  => ['k', AggregateOffset+1*2],
  )
  def test_single_max_data_size(data)
    fixed, expected = data
    config = 'data_key a'
    config += "\nfixed_partition_key #{fixed}" unless fixed.nil?
    d = create_driver(default_config + config)
    d.instance.log.out.flush_logs = false
    offset = d.instance.offset
    assert_equal expected, offset
    time = event_time("2011-01-02 13:14:15 UTC")
    d.run(default_tag: "test") do
      d.feed(time, {"a"=>data_of(1*MB-offset+1)}) # exceeded
    end
    assert_equal 0, @server.records.size
    assert_equal 0, @server.error_count
    assert_equal 1, d.instance.log.out.logs.size
  end

  data(
    'random' => [nil, AggregateOffset+32*2],
    'fixed'  => ['k', AggregateOffset+1*2],
  )
  def test_aggregated_max_data_size(data)
    fixed, expected = data
    config = 'data_key a'
    config += "\nfixed_partition_key #{fixed}" unless fixed.nil?
    d = create_driver(default_config + config)
    d.instance.log.out.flush_logs = false
    offset = d.instance.offset
    assert_equal expected, offset
    time = event_time("2011-01-02 13:14:15 UTC")
    d.run(default_tag: "test") do
      d.feed(time, {"a"=>data_of(512*KB-offset)})
      d.feed(time, {"a"=>data_of(512*KB+1)}) # can't be aggregated
    end
    assert_equal 0, d.instance.log.out.logs.size
    assert_equal 2, @server.records.size
    assert_equal 2, @server.requests.size
  end

  def test_multibyte_input
    d = create_driver(default_config)
    time = event_time("2011-01-02 13:14:15 UTC")
    record = {"a" => "てすと"}
    d.run(default_tag: "test") do
      d.feed(time, record)
    end
    assert_equal 0, d.instance.log.out.logs.size
    assert_equal record.to_json.b, @server.records.first
  end

  def test_record_count
    @server.enable_random_error
    d = create_driver
    d.instance.log.out.flush_logs = false
    time = event_time("2011-01-02 13:14:15 UTC")
    count = 100
    d.run(default_tag: "test") do
      count.times do
        d.feed(time, {"a"=>1})
      end
    end
    assert_equal count, @server.records.size
    assert @server.error_count > 0
    assert @server.raw_records.size < count
  end
end
