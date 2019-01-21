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
require 'fluent/plugin/out_kinesis_firehose'

class KinesisFirehoseOutputTest < Test::Unit::TestCase
  KB = 1024
  MB = 1024 * KB

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
      delivery_stream_name test-stream
      log_level error

      retries_on_batch_request 10
      endpoint https://localhost:#{@server.port}
      ssl_verify_peer false
    ]
  end

  def create_driver(conf = default_config)
    Fluent::Test::Driver::Output.new(Fluent::Plugin::KinesisFirehoseOutput) do
    end.configure(conf)
  end

  def self.data_of(size, char = 'a')
    new_line_size = 1
    char.b * ((size - new_line_size)/char.b.size)
  end

  def data_of(size, char = 'a')
    self.class.data_of(size, char)
  end

  def test_configure
    d = create_driver
    assert_equal 'test-stream', d.instance.delivery_stream_name
    assert_equal 'ap-northeast-1' , d.instance.region
  end

  def test_region
    d = create_driver(default_config + "region us-east-1")
    assert_equal 'us-east-1', d.instance.region
  end

  data(
    'json' => ['json', "{\"a\":1,\"b\":2}\n"],
    'ltsv' => ['ltsv', "a:1\tb:2\n"],
  )
  def test_format(data)
    formatter, expected = data
    d = create_driver(default_config + "<format>\n@type #{formatter}\n</format>")
    driver_run(d, [{"a"=>1,"b"=>2}])
    assert_equal expected, @server.records.first
  end

  data(
    'json' => ['json', '{"a":1,"b":2}'],
    'ltsv' => ['ltsv', "a:1\tb:2"],
  )
  def test_format_without_append_new_line(data)
    formatter, expected = data
    d = create_driver(default_config + "<format>\n@type #{formatter}\n</format>\nappend_new_line false")
    driver_run(d, [{"a"=>1,"b"=>2}])
    assert_equal expected, @server.records.first
  end

  def test_data_key
    d = create_driver(default_config + "data_key a")
    driver_run(d, [{"a"=>1,"b"=>2}, {"b"=>2}])
    assert_equal "1\n", @server.records.first
    assert_equal 1, @server.records.size
    assert_equal 1, d.instance.log.out.logs.size
  end

  def test_data_key_without_append_new_line
    d = create_driver(default_config + "data_key a\nappend_new_line false")
    driver_run(d, [{"a"=>1,"b"=>2}, {"b"=>2}])
    assert_equal "1", @server.records.first
    assert_equal 1, @server.records.size
    assert_equal 1, d.instance.log.out.logs.size
  end

  def test_max_record_size
    d = create_driver(default_config + "data_key a")
    driver_run(d, [
      {"a"=>data_of(1*MB)},
      {"a"=>data_of(1*MB+1)}, # exceeded
    ])
    assert_equal 1, @server.records.size
    assert_equal 1, d.instance.log.out.logs.size
  end

  def test_max_record_size_multi_bytes
    d = create_driver(default_config + "data_key a")
    driver_run(d, [
      {"a"=>data_of(1*MB, 'あ')},
      {"a"=>data_of(1*MB+6, 'あ')}, # exceeded
    ])
    assert_equal 1, @server.records.size
    assert_equal 1, d.instance.log.out.logs.size
  end

  def test_single_max_record_size
    d = create_driver(default_config + "data_key a")
    driver_run(d, [
      {"a"=>data_of(1*MB+1)}, # exceeded
    ])
    assert_equal 0, @server.records.size
    assert_equal 0, @server.error_count
    assert_equal 1, d.instance.log.out.logs.size
  end

  def test_max_record_size_without_append_new_line
    d = create_driver(default_config + "append_new_line false\ndata_key a")
    driver_run(d, [
      {"a"=>data_of(1*MB+1)},
      {"a"=>data_of(1*MB+2)}, # exceeded
    ])
    assert_equal 1, @server.records.size
    assert_equal 1, d.instance.log.out.logs.size
  end

  data(
    'split_by_count'           => [Array.new(501, data_of(1*KB)),                     [500,1]],
    'split_by_size'            => [Array.new(257, data_of(16*KB)),                    [256,1]],
    'split_by_size_with_space' => [Array.new(255, data_of(16*KB))+[data_of(16*KB+1)], [255,1]],
    'no_split_by_size'         => [Array.new(256, data_of(16*KB)),                    [256]],
  )
  def test_batch_request(data)
    records, expected = data
    d = create_driver(default_config + "data_key a")
    driver_run(d, records.map{|record| {'a' => record}})
    assert_equal records.size, @server.records.size
    assert_equal expected, @server.count_per_requests
    @server.size_per_requests.each do |size|
      assert size <= 4*MB
    end
    @server.count_per_requests.each do |count|
      assert count <= 500
    end
  end

  def test_multibyte_input
    d = create_driver(default_config)
    record = {"a" => "てすと"}
    driver_run(d, [record])
    assert_equal 0, d.instance.log.out.logs.size
    assert_equal record.to_json.b + "\n", @server.records.first
  end

  def test_record_count
    @server.enable_random_error
    d = create_driver
    count = 10
    driver_run(d, count.times.map{|i|{"a"=>1}})
    assert_equal count, @server.records.size
    assert @server.failed_count > 0
    assert @server.error_count > 0
  end

  # Debug test case for the issue that it fails to flush the buffer
  # https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/133
  def test_chunk_limit_size_for_debug
    config = <<-CONF
      log_level warn
      <buffer>
        chunk_limit_size "1m"
      </buffer>
    CONF
    d = create_driver(default_config + config)
    d.run(wait_flush_completion: true, force_flush_retry: true) do
      10.times do
        time = Fluent::EventTime.now
        events = Array.new(Kernel.rand(3000..5000)).map { [time, { msg: "x" * 256 }] }
        d.feed("test", events)
      end
    end
    d.logs.each { |log_record| assert_not_match(/NoMethodError/, log_record) }
  end
end
