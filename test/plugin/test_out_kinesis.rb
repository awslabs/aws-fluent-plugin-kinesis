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

  CONFIG_WITH_MORE_OPTIONS = %[
    use_iam_role true
    stream_name test_stream
    region us-east-1
    partition_key test_partition_key
    partition_key_expr record
    explicit_hash_key test_hash_key
    explicit_hash_key_expr record
    order_events true
  ]

  def create_driver(conf = CONFIG, tag='test')
    Fluent::Test::BufferedOutputTestDriver
      .new(FluentPluginKinesis::OutputFilter, tag).configure(conf)
  end

  def create_driver_with_more_options(
    conf = CONFIG_WITH_MORE_OPTIONS, 
    tag='test'
  )
    Fluent::Test::BufferedOutputTestDriver
      .new(FluentPluginKinesis::OutputFilter, tag).configure(conf)
  end

  def create_mock_clinet
    client = mock(Object.new)
    mock(Aws::Kinesis).new({}) { client }
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
    d = create_driver_with_more_options
    assert_equal true, d.instance.use_iam_role
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

  def test_format

    d = create_driver

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    d.emit({"test_partition_key"=>"key1","a"=>1}, time)
    d.emit({"test_partition_key"=>"key2","a"=>2}, time)

    d.expect_format %!\x83\xABstream_name\xABtest_stream\xA4data\xDA\x00jeyJ0ZXN0X3BhcnRpdGlvbl9rZXkiOiJrZXkxIiwiYSI6MSwidGltZSI6IjIw\nMTEtMDEtMDJUMTM6MTQ6MTVaIiwidGFnIjoidGVzdCJ9\n\xADpartition_key\xA4key1!.force_encoding('ascii-8bit')
    d.expect_format %!\x83\xABstream_name\xABtest_stream\xA4data\xDA\x00jeyJ0ZXN0X3BhcnRpdGlvbl9rZXkiOiJrZXkyIiwiYSI6MiwidGltZSI6IjIw\nMTEtMDEtMDJUMTM6MTQ6MTVaIiwidGFnIjoidGVzdCJ9\n\xADpartition_key\xA4key2!.force_encoding('ascii-8bit')

    client = create_mock_clinet
    client.describe_stream(stream_name: 'test_stream')
    client.put_record(stream_name: "test_stream", data: "eyJ0ZXN0X3BhcnRpdGlvbl9rZXkiOiJrZXkxIiwiYSI6MSwidGltZSI6IjIw\nMTEtMDEtMDJUMTM6MTQ6MTVaIiwidGFnIjoidGVzdCJ9\n", partition_key: "key1")
    client.put_record(stream_name: "test_stream", data: "eyJ0ZXN0X3BhcnRpdGlvbl9rZXkiOiJrZXkyIiwiYSI6MiwidGltZSI6IjIw\nMTEtMDEtMDJUMTM6MTQ6MTVaIiwidGFnIjoidGVzdCJ9\n", partition_key: "key2")

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
    d = create_driver_with_more_options
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
  end

end
