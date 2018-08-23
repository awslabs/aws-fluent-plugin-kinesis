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
require 'fluent/plugin/kinesis'

module Fluent
  module Plugin
    class KinesisFakeOutput < KinesisOutput
      RequestType = :fake
      BatchRequestLimitCount = 500
      BatchRequestLimitSize  = 4*1024*1024
      include KinesisHelper::API::BatchRequest

      def client
        @client ||= Aws::FakeClient.new
      end

      def format(tag, time, record)
        format_for_api do
          [@data_formatter.call(tag, time, record)]
        end
      end

      def write(chunk)

      end
    end
  end
end

module Aws
  class FakeClient
    def config
      Struct.new(:region).new('us-east-1')
    end
  end
end

class KinesisOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  def teardown
  end

  def default_config
    %[
      log_level error
    ]
  end

  def create_driver(conf = default_config)
    Fluent::Test::Driver::Output.new(Fluent::Plugin::KinesisFakeOutput) do
    end.configure(conf)
  end

  def test_time_key
    d = create_driver(default_config + "<inject>\ntime_key time\nutc true\n</inject>")
    record = {"a"=>"foo"}
    time = event_time("2011-01-02 13:14:15.161718190 UTC")
    driver_run(d, [record], time: time)
    result = JSON.parse(MessagePack.unpack(d.formatted.first).first)
    assert_equal record.merge("time"=> "2011-01-02T13:14:15.161718190+0000"), result
  end

  data(
    'zlib' => ['zlib', Zlib::Deflate.deflate("foo")],
  )
  def test_format_compression(data)
    compression, expected = data
    d = create_driver(default_config + "data_key a\ncompression #{compression}")
    driver_run(d, [{"a"=>"foo"}])
    result = d.formatted.first
    assert_equal expected, MessagePack.unpack(result).first
  end

  data(
    'not_exceeded'      => [{"a"=>"a"*30}, ["a".b*30].to_msgpack],
    'exceeded'          => [{"a"=>"a"*31}, ''],
    'not_exceeded_utf8' => [{"a"=>"あ"*10}, ["あ".b*10].to_msgpack],
    'exceeded_utf8'     => [{"a"=>"あ"*11}, ''],
  )
  def test_format_max_record_size(data)
    record, expected = data
    d = create_driver(default_config + "data_key a\nmax_record_size 30")
    driver_run(d, [record])
    assert_equal expected, d.formatted.first
    assert_equal expected == '' ? 1 : 0, d.instance.log.out.logs.size
  end

  data(
    '1'     => [1,   "1"],
    '5'     => [5,   "12345"],
    '100'   => [100, "123456789"],
  )
  def test_truncate_max_size(data)
    max_size, expected = data
    d = create_driver(default_config + "log_truncate_max_size #{max_size}")
    result = d.instance.send(:truncate, "123456789")
    assert_equal expected, result
  end

  def test_reduce_max_size_error_message
    record = {"a"=>"a"*1025}
    d = create_driver(default_config + "data_key a\nmax_record_size 1024\nlog_truncate_max_size 100")
    driver_run(d, [record])
    assert_equal 1, d.instance.log.out.logs.size
    assert_operator d.instance.log.out.logs.first.size, :<, record.to_s.size
  end
end
