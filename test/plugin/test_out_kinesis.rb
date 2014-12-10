# Copyright 2014 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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

require 'helper'

class KinesisOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    aws_key_id test_key_id
    aws_sec_key test_sec_key
    stream_name test_stream
    region us-east-1
    partition_key test_partition_key
  ]

  def create_driver(conf = CONFIG, tag='test')
    Fluent::Test::BufferedOutputTestDriver
      .new(FluentPluginKinesis::OutputFilter, tag).configure(conf)
  end

  def create_mock_client
    client = mock(Object.new)
    mock(Aws::Kinesis::Client).new({}) { client }
    return client
  end

  def test_configure
    d = create_driver
    assert_equal 'test_key_id', d.instance.aws_key_id
    assert_equal 'test_sec_key', d.instance.aws_sec_key
    assert_equal 'test_stream', d.instance.stream_name
    assert_equal 'us-east-1', d.instance.region
    assert_equal 'test_partition_key', d.instance.partition_key
  end

  def test_configure_with_more_options

    conf = %[
      stream_name test_stream
      region us-east-1
      partition_key test_partition_key
      partition_key_expr record
      explicit_hash_key test_hash_key
      explicit_hash_key_expr record
      order_events true
    ]
    d = create_driver(conf)
    assert_equal 'test_stream', d.instance.stream_name
    assert_equal 'us-east-1', d.instance.region
    assert_equal 'test_partition_key', d.instance.partition_key
    assert_equal 'Proc',
      d.instance.instance_variable_get(:@partition_key_proc).class.to_s
    assert_equal 'test_hash_key', d.instance.explicit_hash_key
    assert_equal 'Proc',
      d.instance.instance_variable_get(:@explicit_hash_key_proc).class.to_s
    assert_equal 'a',
      d.instance.instance_variable_get(:@partition_key_proc).call('a')
    assert_equal 'a',
      d.instance.instance_variable_get(:@explicit_hash_key_proc).call('a')
    assert_equal true, d.instance.order_events
    assert_equal nil, d.instance.instance_variable_get(:@sequence_number_for_ordering)
  end

  def test_mode_configuration

    conf = %[
      stream_name test_stream
      region us-east-1
      partition_key test_partition_key
    ]
    d = create_driver(conf)
    assert_equal(false, d.instance.order_events)
    assert_equal(false, d.instance.instance_variable_get(:@parallel_mode))

    conf = %[
      stream_name test_stream
      region us-east-1
      partition_key test_partition_key
      order_events true
    ]
    d = create_driver(conf)
    assert_equal(true, d.instance.order_events)
    assert_equal(false, d.instance.instance_variable_get(:@parallel_mode))

    conf = %[
      stream_name test_stream
      region us-east-1
      partition_key test_partition_key
      num_threads 1
    ]
    d = create_driver(conf)
    assert_equal(false, d.instance.order_events)
    assert_equal(false, d.instance.instance_variable_get(:@parallel_mode))

    conf = %[
      stream_name test_stream
      region us-east-1
      partition_key test_partition_key
      num_threads 2
    ]
    d = create_driver(conf)
    assert_equal(false, d.instance.order_events)
    assert_equal(true, d.instance.instance_variable_get(:@parallel_mode))

    conf = %[
      stream_name test_stream
      region us-east-1
      partition_key test_partition_key
      detach_process 1
    ]
    d = create_driver(conf)
    assert_equal(false, d.instance.order_events)
    assert_equal(true, d.instance.instance_variable_get(:@parallel_mode))

    conf = %[
      stream_name test_stream
      region us-east-1
      partition_key test_partition_key
      order_events true
      detach_process 1
      num_threads 2
    ]
    d = create_driver(conf)
    assert_equal(false, d.instance.order_events)
    assert_equal(true, d.instance.instance_variable_get(:@parallel_mode))

  end

  def test_format

    d = create_driver

    data1 = {"test_partition_key"=>"key1","a"=>1,"time"=>"2011-01-02T13:14:15Z","tag"=>"test"}
    data2 = {"test_partition_key"=>"key2","a"=>2,"time"=>"2011-01-02T13:14:15Z","tag"=>"test"}

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    d.emit(data1, time)
    d.emit(data2, time)

    d.expect_format({
      'data' => data1.to_json,
      'partition_key' => 'key1' }.to_msgpack
    )
    d.expect_format({
      'data' => data2.to_json,
      'partition_key' => 'key2' }.to_msgpack
    )

    client = create_mock_client
    client.describe_stream(stream_name: 'test_stream')
    client.put_records(
      stream_name: 'test_stream',
      records: [
        {
          data: data1.to_json,
          partition_key: 'key1'
        },
        {
          data: data2.to_json,
          partition_key: 'key2'
        }
      ]
    ) { {} }

    d.run
  end

  def test_order_events

    d = create_driver(CONFIG + "\norder_events true")

    data1 = {"test_partition_key"=>"key1","a"=>1,"time"=>"2011-01-02T13:14:15Z","tag"=>"test"}
    data2 = {"test_partition_key"=>"key2","a"=>2,"time"=>"2011-01-02T13:14:15Z","tag"=>"test"}

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    d.emit(data1, time)
    d.emit(data2, time)

    d.expect_format({
      'data' => data1.to_json,
      'partition_key' => 'key1' }.to_msgpack
    )
    d.expect_format({
      'data' => data2.to_json,
      'partition_key' => 'key2' }.to_msgpack
    )

    client = create_mock_client
    client.describe_stream(stream_name: 'test_stream')
    client.put_record(
      data: data1.to_json,
      partition_key: 'key1',
      stream_name: 'test_stream'
    ) { {sequence_number: 1} }
    client.put_record(
      data: data2.to_json,
      partition_key: 'key2',
      sequence_number_for_ordering: 1,
      stream_name: 'test_stream'
    ) { {} }

    d.run
  end

  def test_format_at_lowlevel
    d = create_driver
    data = {"test_partition_key"=>"key1","a"=>1}
    assert_equal(
        MessagePack.pack({
            "data"              => data.to_json,
            "partition_key"     => "key1"
        }),
        d.instance.format('test','test',data)
    )
  end

  def test_format_at_lowlevel_with_more_options

    conf = %[
      stream_name test_stream
      region us-east-1
      partition_key test_partition_key
      partition_key_expr record
      explicit_hash_key test_hash_key
      explicit_hash_key_expr record
      order_events true
    ]

    d = create_driver(conf)
    data = {"test_partition_key"=>"key1","test_hash_key"=>"hash1","a"=>1}
    assert_equal(
        MessagePack.pack({
            "data"              => data.to_json,
            "partition_key"     => "key1",
            "explicit_hash_key" => "hash1"
        }),
        d.instance.format('test','test',data)
    )
  end

  def test_get_key
    d = create_driver
    assert_equal(
      "1",
      d.instance.send(:get_key, "partition_key", {"test_partition_key" => 1})
    )

    assert_equal(
      "abc",
      d.instance.send(:get_key, "partition_key", {"test_partition_key" => "abc"})
    )

    d = create_driver(%[
      random_partition_key true
      stream_name test_stream
      region us-east-1'
    ])

    assert_match(
      /\A[\da-f-]{36}\z/,
      d.instance.send(:get_key, 'foo', 'bar')
    )

    d = create_driver(%[
      random_partition_key true
      partition_key test_key
      stream_name test_stream
      region us-east-1'
    ])

    assert_match(
      /\A[\da-f-]{36}\z/,
      d.instance.send(
        :get_key,
        'partition_key',
        {"test_key" => 'key1'}
      )
    )

    d = create_driver(%[
      random_partition_key true
      partition_key test_key
      explicit_hash_key explicit_key
      stream_name test_stream
      region us-east-1'
    ])

    assert_match(
      /\A[\da-f-]{36}\z/,
      d.instance.send(
        :get_key,
        'partition_key',
        {"test_key" => 'key1', "explicit_key" => 'key2'}
      )
    )
  end

  def test_record_exceeds_max_size
    d = create_driver
    string = ''
    (1..1024).each{ string = string + '1' }
    assert_equal(
      false,
      d.instance.send(:record_exceeds_max_size?,string)
    )

    string = ''
    (1..(1024*50)).each{ string = string + '1' }
    assert_equal(
      false,
      d.instance.send(:record_exceeds_max_size?,string)
    )

    string = ''
    (1..(1024*51)).each{ string = string + '1' }
    assert_equal(
      true,
      d.instance.send(:record_exceeds_max_size?,string)
    )
  end

  def test_build_records_array_to_put
    d = create_driver

    data_list = []
    (0..500).each do |n|
      data_list.push({data: n.to_s})
    end
    result = d.instance.send(:build_records_array_to_put,data_list)
    assert_equal(2,result.length)
    assert_equal(500,result[0].length)
    assert_equal(1,result[1].length)

    data_list = []
    (0..1400).each do
      data_list.push({data: '1'})
    end
    result = d.instance.send(:build_records_array_to_put,data_list)
    assert_equal(3,result.length)
    assert_equal(500,result[0].length)
    assert_equal(500,result[1].length)
    assert_equal(401,result[2].length)

    data_list = []
    data_string = ''
    (0..(1024*30)).each do
      data_string = data_string + '1'
    end
    (0..500).each do
      data_list.push({data: data_string})
    end
    result = d.instance.send(:build_records_array_to_put,data_list)
    assert_equal(3,result.length)
    assert_equal(170,result[0].length)
    assert_operator(
      1024 * 1024 *5, :>,
      result[0].reduce(0){|sum,i| sum + i[:data].length}
    )
    assert_equal(170,result[1].length)
    assert_operator(
      1024 * 1024 *5, :>,
      result[1].reduce(0){|sum,i| sum + i[:data].length}
    )
    assert_equal(161,result[2].length)
    assert_operator(
      1024 * 1024 *5, :>,
      result[2].reduce(0){|sum,i| sum + i[:data].length}
    )
  end

  def test_build_data_to_put
    d = create_driver
    assert_equal(
      {key: 1},
      d.instance.send(:build_data_to_put,{"key"=>1})
    )
  end

  def test_calculate_sleep_duration
    d = create_driver
    assert_operator(
        1, :>,
        d.instance.send(:calculate_sleep_duration,0)
    )
    assert_operator(
        2, :>,
        d.instance.send(:calculate_sleep_duration,1)
    )
    assert_operator(
        4, :>,
        d.instance.send(:calculate_sleep_duration,2)
    )
  end
end
