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

require_relative '../helper'
require 'fluent/plugin/out_kinesis_producer'

class KinesisProducerOutputTest < Test::Unit::TestCase
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

  def base_config
    %[
      log_level error

      <kinesis_producer>
        custom_endpoint localhost
        port #{@server.port}
        verify_certificate false
        log_level error
      </kinesis_producer>
    ]
  end

  def default_config
    "stream_name test-stream " + base_config
  end

  def create_driver(conf = default_config)
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::KinesisProducerOutput) do
    end.configure(conf)
  end

  def test_configure
    d = create_driver
    assert_equal 'test-stream', d.instance.stream_name
    assert_equal 'ap-northeast-1', d.instance.region
    assert_equal 'localhost',   d.instance.kinesis_producer.custom_endpoint
    assert_equal @server.port,  d.instance.kinesis_producer.port
    assert_equal false,         d.instance.kinesis_producer.verify_certificate
  end

  def test_configure_with_stream_name_prefix
    d = create_driver("stream_name_prefix test-stream-")
    assert_equal 'test-stream-', d.instance.stream_name_prefix
    assert_nil d.instance.stream_name
  end

  def test_configure_without_stream_name_or_prefix
    assert_raise(Fluent::ConfigError) { d = create_driver("") }
  end

  def test_configure_with_stream_name_and_prefix
    assert_raise(Fluent::ConfigError) { d = create_driver("stream_name test-stream\nstream_name_prefix test-stream-") }
  end

  def test_configure_without_section
    d = create_driver("stream_name test-stream")
    assert_not_nil d.instance.kinesis_producer
  end

  def test_configure_with_empty_section
    d = create_driver("stream_name test-stream\n<kinesis_producer>\n</kinesis_producer>")
    assert_not_nil d.instance.kinesis_producer
  end

  def test_region
    d = create_driver(default_config + "region us-west-2")
    assert_equal 'us-west-2', d.instance.region
  end

  def test_stream_name
    # First record using stream_name_prefix + tag
    d = create_driver(base_config + "stream_name_prefix test-stream-")
    d.emit({"a"=>1,"b"=>2})
    d.run
    # Second record using explicit stream_name
    d = create_driver
    d.emit({"a"=>1,"b"=>2})
    d.run

    records = @server.detailed_records
    assert_equal 2, records.size
    assert_equal "test-stream-test", records[0][:stream_name]
    assert_equal "test-stream", records[1][:stream_name]
  end

  data(
    'json' => ['json', '{"a":1,"b":2}'],
    'ltsv' => ['ltsv', "a:1\tb:2"],
  )
  def test_format(data)
    formatter, expected = data
    d = create_driver(default_config + "formatter #{formatter}")
    d.emit({"a"=>1,"b"=>2})
    d.run
    assert_equal expected, @server.records.first
  end

  def test_partition_key_not_found
    d = create_driver(default_config + "partition_key partition_key")
    d.emit({"a"=>1})
    d.run
    assert_equal 0, @server.records.size
    assert_equal 1, d.instance.log.logs.size
  end

  def test_data_key
    d = create_driver(default_config + "data_key a")
    d.emit({"a"=>1,"b"=>2})
    d.emit({"b"=>2})
    d.run
    assert_equal "1", @server.records.first
    assert_equal 1, @server.records.size
    assert_equal 1, d.instance.log.logs.size
  end

  def test_max_record_size
    d = create_driver
    d.emit({"a"=>"a"*(1024*1024-'{"a":""}'.size)})
    d.emit({"a"=>"a"*(1024*1024-'{"a":""}'.size+1)}) # exceeded
    d.run
    assert_equal 1, @server.records.size
    assert_equal 1, d.instance.log.logs.size
  end

  def test_record_count
    @server.enable_random_error
    d = create_driver
    count = 200
    count.times do
      d.emit({"a"=>1})
    end

    d.run

    assert_equal count, @server.records.size
    assert @server.failed_count > 0
    assert @server.error_count > 0
    assert @server.aggregated_count > 0
  end
end
