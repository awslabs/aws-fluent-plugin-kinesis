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
  AggregateOffset = Fluent::Plugin::KinesisHelper::Aggregator::Mixin::AggregateOffset
  RecordOffset = Fluent::Plugin::KinesisHelper::Aggregator::Mixin::RecordOffset

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
    Fluent::Test::Driver::Output.new(Fluent::Plugin::KinesisStreamsAggregatedOutput) do
    end.configure(conf)
  end

  def self.data_of(size, char = 'a')
    offset_size = RecordOffset
    char.b * ((size - offset_size)/char.b.size)
  end

  def data_of(size, char = 'a')
    self.class.data_of(size, char)
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
    d = create_driver(default_config + "<format>\n@type #{formatter}\n</format>")
    driver_run(d, [{"a"=>1,"b"=>2}])
    assert_equal (expected + "\n").b, @server.records.first
  end

  data(
    'json' => ['json', '{"a":1,"b":2}'],
    'ltsv' => ['ltsv', "a:1\tb:2"],
  )
  def test_format_with_chomp_record(data)
    formatter, expected = data
    d = create_driver(default_config + "<format>\n@type #{formatter}\n</format>\nchomp_record true")
    driver_run(d, [{"a"=>1,"b"=>2}])
    assert_equal expected.b, @server.records.first
  end

  def test_data_key
    d = create_driver(default_config + "data_key a")
    driver_run(d, [{"a"=>1,"b"=>2}, {"b"=>2}])
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
    offset = d.instance.offset
    assert_equal expected, offset
    driver_run(d, [
      {"a"=>data_of(1*MB-offset)},
      {"a"=>data_of(1*MB-offset+1)}, # exceeded
    ])
    assert_equal 1, d.instance.log.out.logs.size
    assert_equal 1, @server.records.size
  end

  data(
    'random' => [nil, AggregateOffset+32*2],
    'fixed'  => ['k', AggregateOffset+1*2],
  )
  def test_max_data_size_multi_bytes(data)
    fixed, expected = data
    config = 'data_key a'
    config += "\nfixed_partition_key #{fixed}" unless fixed.nil?
    d = create_driver(default_config + config)
    offset = d.instance.offset
    assert_equal expected, offset
    driver_run(d, [
      {"a"=>data_of(1*MB-offset, 'あ')},
      {"a"=>data_of(1*MB-offset+6, 'あ')}, # exceeded
    ])
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
    offset = d.instance.offset
    assert_equal expected, offset
    driver_run(d, [
      {"a"=>data_of(1*MB-offset+1)}, # exceeded
    ])
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
    offset = d.instance.offset
    assert_equal expected, offset
    driver_run(d, [
      {"a"=>data_of(512*KB-offset)},
      {"a"=>data_of(512*KB+1)}, # can't be aggregated
    ])
    assert_equal 0, d.instance.log.out.logs.size
    assert_equal 2, @server.records.size
    assert_equal 2, @server.requests.size
  end

  def test_multibyte_input
    d = create_driver(default_config)
    record = {"a" => "てすと"}
    driver_run(d, [record])
    assert_equal 0, d.instance.log.out.logs.size
    assert_equal (record.to_json + "\n").b, @server.records.first
  end

  data(
    '10B*100,000'  => [10, 100000],
    '100B*10,000'  => [100, 10000],
    '1,000B*1,000' => [1000, 1000],
    '10,000B*100'  => [10000, 100],
    '100,000B*10'  => [100000, 10],
  )
  def test_extream_case(data)
    size, count = data
    d = create_driver(default_config+"data_key a")
    record = {"a"=>"a"*size}
    driver_run(d, count.times.map{|i|record})
    assert_equal count, @server.records.size
    assert @server.raw_records.size < count
  end

  def test_record_count
    @server.enable_random_error
    d = create_driver
    count = 100
    driver_run(d, count.times.map{|i|{"a"=>1}})
    assert_equal count, @server.records.size
    assert @server.error_count > 0
    assert @server.raw_records.size < count
  end

  class PlaceholdersTest < self
    def test_tag_placeholder
      d = create_driver(
        Fluent::Config::Element.new('ROOT', '', {
                                      "stream_name"  => "stream-placeholder-${tag}",
                                      "@log_level" => "error",
                                      "retries_on_batch_request" => 10,
                                      "endpoint" => "https://localhost:#{@server.port}",
                                      "ssl_verify_peer" => false,
                                    },[
                                      Fluent::Config::Element.new('buffer', 'tag', {
                                                                    '@type' => 'memory',
                                                                  }, [])
                                    ])
      )

      record = {"a" => "test"}
      driver_run(d, [record])
      assert_equal("stream-placeholder-test", @server.detailed_records.first[:stream_name])
      assert_equal 0, d.instance.log.out.logs.size
      assert_equal (record.to_json + "\n").b, @server.records.first
    end

    def test_time_placeholder
      d = create_driver(
        Fluent::Config::Element.new('ROOT', '', {
                                      "stream_name"  => "stream-placeholder-${tag}-%Y%m%d",
                                      "@log_level" => "error",
                                      "retries_on_batch_request" => 10,
                                      "endpoint" => "https://localhost:#{@server.port}",
                                      "ssl_verify_peer" => false,
                                    },[
                                      Fluent::Config::Element.new('buffer', 'tag, time', {
                                                                    '@type' => 'memory',
                                                                    'timekey' => 3600
                                                                  }, [])
                                    ])
      )

      record = {"a" => "test"}
      time = event_time
      driver_run(d, [record], time: time)
      assert_equal("stream-placeholder-test-#{Time.now.strftime("%Y%m%d")}",
                   @server.detailed_records.first[:stream_name])
      assert_equal 0, d.instance.log.out.logs.size
      assert_equal (record.to_json + "\n").b, @server.records.first
    end

    def test_custom_placeholder
      d = create_driver(
        Fluent::Config::Element.new('ROOT', '', {
                                      "stream_name"  => "stream-placeholder-${$.key.nested}",
                                      "@log_level" => "error",
                                      "retries_on_batch_request" => 10,
                                      "endpoint" => "https://localhost:#{@server.port}",
                                      "ssl_verify_peer" => false,
                                    },[
                                      Fluent::Config::Element.new('buffer', '$.key.nested', {
                                                                    '@type' => 'memory',
                                                                  }, [])
                                    ])
      )

      record = {"key" => {"nested" => "nested-value"}}
      driver_run(d, [record])
      assert_equal("stream-placeholder-nested-value", @server.detailed_records.first[:stream_name])
      assert_equal 0, d.instance.log.out.logs.size
      assert_equal (record.to_json + "\n").b, @server.records.first
    end
  end

  # Debug test case for the issue that it fails to flush the buffer
  # https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/133
  #def test_chunk_limit_size_for_debug
  #  config = <<-CONF
  #    log_level warn
  #    <buffer>
  #      chunk_limit_size "1m"
  #    </buffer>
  #  CONF
  #  d = create_driver(default_config + config)
  #  d.run(wait_flush_completion: true, force_flush_retry: true) do
  #    10.times do
  #      time = Fluent::EventTime.now
  #      events = Array.new(Kernel.rand(3000..5000)).map { [time, { msg: "x" * 256 }] }
  #      d.feed("test", events)
  #    end
  #  end
  #  d.logs.each { |log_record| assert_not_match(/NoMethodError/, log_record) }
  #end
end
