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

  def create_mock_clinet
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

    data1 = {"test_partition_key"=>"key1","a"=>1}
    data2 = {"test_partition_key"=>"key2","a"=>2}

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    d.emit(data1, time)
    d.emit(data2, time)

    d.expect_format({
      'stream_name' => 'test_stream',
      'data' => Base64.encode64(data1.to_json),
      'partition_key' => 'key1' }.to_msgpack
    )
    d.expect_format({
      'stream_name' => 'test_stream',
      'data' => Base64.encode64(data2.to_json),
      'partition_key' => 'key2' }.to_msgpack
    )

    client = create_mock_clinet
    client.describe_stream(stream_name: 'test_stream')
    client.put_record(
      stream_name: 'test_stream',
      data: Base64.encode64(data1.to_json),
      partition_key: 'key1'
    )
    client.put_record(
      stream_name: 'test_stream',
      data: Base64.encode64(data2.to_json),
      partition_key: 'key2'
    )

    d.run
  end

  def test_format_at_lowlevel
    d = create_driver
    data = {"test_partition_key"=>"key1","a"=>1}
    assert_equal(
        MessagePack.pack({
            "stream_name"       => "test_stream",
            "data"              => Base64.encode64(data.to_json),
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
            "stream_name"       => "test_stream",
            "data"              => Base64.encode64(data.to_json),
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

end
