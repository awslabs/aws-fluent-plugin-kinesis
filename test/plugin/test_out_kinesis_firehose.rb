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
require 'fluent/plugin/out_kinesis_firehose'

class KinesisFirehoseOutputTest < Test::Unit::TestCase
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
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::KinesisFirehoseOutput) do
    end.configure(conf)
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
    'json' => ['json', '{"a":1,"b":2}'],
    'ltsv' => ['ltsv', "a:1\tb:2"],
  )
  def test_format(data)
    formatter, expected = data
    d = create_driver(default_config + "formatter #{formatter}")
    d.emit({"a"=>1,"b"=>2})
    d.run
    assert_equal expected+"\n", @server.records.first
  end

  data(
    'json' => ['json', '{"a":1,"b":2}'],
    'ltsv' => ['ltsv', "a:1\tb:2"],
  )
  def test_format_without_append_new_line(data)
    formatter, expected = data
    d = create_driver(default_config + "formatter #{formatter}\nappend_new_line false")
    d.emit({"a"=>1,"b"=>2})
    d.run
    assert_equal expected, @server.records.first
  end

  def test_data_key
    d = create_driver(default_config + "data_key a")
    d.emit({"a"=>1,"b"=>2})
    d.emit({"b"=>2})
    d.run
    assert_equal "1\n", @server.records.first
    assert_equal 1, @server.records.size
    assert_equal 1, d.instance.log.logs.size
  end

  def test_data_key_without_append_new_line
    d = create_driver(default_config + "data_key a\nappend_new_line false")
    d.emit({"a"=>1,"b"=>2})
    d.emit({"b"=>2})
    d.run
    assert_equal "1", @server.records.first
    assert_equal 1, @server.records.size
    assert_equal 1, d.instance.log.logs.size
  end

  def test_max_record_size
    d = create_driver
    d.emit({"a"=>"a"*(1024*1024-'{"a":""}n'.size)})
    d.emit({"a"=>"a"*(1024*1024-'{"a":""}n'.size+1)}) # exceeded
    d.run
    assert_equal 1, @server.records.size
    assert_equal 1, d.instance.log.logs.size
  end

  def test_max_record_size_without_append_new_line
    d = create_driver(default_config + "append_new_line false")
    d.emit({"a"=>"a"*(1024*1024-'{"a":""}'.size)})
    d.emit({"a"=>"a"*(1024*1024-'{"a":""}'.size+1)}) # exceeded
    d.run
    assert_equal 1, @server.records.size
    assert_equal 1, d.instance.log.logs.size
  end

  pad = "{\"data\":\"\"}\n".size
  data(
    'split_by_count'           => [Array.new(501, {data:'a'}),                                        [500,1]],
    'split_by_size'            => [Array.new(257, {data:'a'*(16384-pad)}),                            [256,1]],
    'split_by_size_with_space' => [Array.new(255, {data:'a'*(16384-pad)})+[{data:'a'*(16384-pad+1)}], [255,1]],
    'no_split_by_size'         => [Array.new(255, {data:'a'*(16384-pad)})+[{data:'a'*(16384-pad)}],   [256]],
  )
  def test_batch_request(data)
    records, expected = data
    d = create_driver
    records.each do |record|
      d.emit(record)
    end
    d.run
    assert_equal records.size, @server.records.size
    assert_equal expected, @server.count_per_requests
    @server.size_per_requests.each do |size|
      assert size <= 4*1024*1024
    end
  end

  def test_record_count
    @server.enable_random_error
    d = create_driver
    count = 10
    count.times do
      d.emit({"a"=>1})
    end

    d.run

    assert_equal count, @server.records.size
    assert @server.failed_count > 0
    assert @server.error_count > 0
  end
end
