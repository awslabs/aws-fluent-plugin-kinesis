require 'helper'

class KinesisInputcTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    aws_key_id test_key_id
    aws_sec_key test_sec_key
    region us-east-1
    stream_name test_stream
    tag test
  ]

  def create_driver(conf = CONFIG)
    Fluent::Test::InputTestDriver
      .new(FluentPluginKinesis::Input).configure(conf)
  end

  def create_mock_clinet
    client = mock(Object.new)
    mock(Aws::Kinesis::Client).new({}) { client }
    return client
  end

  def to_stub(obj)
    case obj
    when Array
      obj.map {|v| to_stub(v) }
    when Hash
      OpenStruct.new(Hash[*obj.map {|k, v| [k, to_stub(v)] }.flatten(1)])
    else
      obj
    end
  end

  def test_configure
    d = create_driver(<<-EOS)
      #{CONFIG}
      interval 3
    EOS

    assert_equal 'test_key_id', d.instance.aws_key_id
    assert_equal 'test_sec_key', d.instance.aws_sec_key
    assert_equal 'us-east-1', d.instance.region
    assert_equal 'test_stream', d.instance.stream_name
    assert_equal 'test', d.instance.tag
    assert_equal 3, d.instance.interval
  end

  def test_configure_with_credentials
    d = create_driver(<<-EOS)
      profile default
      credentials_path /home/scott/.aws/credentials
      stream_name test_stream
      region us-east-1
      tag test
    EOS

    assert_equal 'default', d.instance.profile
    assert_equal '/home/scott/.aws/credentials', d.instance.credentials_path
    assert_equal 'test_stream', d.instance.stream_name
    assert_equal 'us-east-1', d.instance.region
    assert_equal 'test', d.instance.tag
  end

  def test_load_client
    client = stub(Object.new)
    client.describe_stream {
      to_stub([
        { stream_description: {
            shards: [
              {
                shard_id: 'shardId-000000000000',
                sequence_number_range: {
                  starting_sequence_number: '12345678901234567890123456789012345678901234567890123456'}}]}}])
    }

    client.get_shard_iterator { {shard_iterator: 'SHARD_ITERATOR'} }

    client.get_records {
      [{
        records: [],
        next_shard_iterator: 'NEXT_SHARD_ITERATOR'
      }]
    }

    stub(Aws::Kinesis::Client).new do |options|
      assert_equal("test_key_id", options[:access_key_id])
      assert_equal("test_sec_key", options[:secret_access_key])
      assert_equal("us-east-1", options[:region])
      client
    end

    d = create_driver
    d.run
  end

  def test_load_client_with_credentials
    client = stub(Object.new)
    client.describe_stream {
      to_stub([
        { stream_description: {
            shards: [
              {
                shard_id: 'shardId-000000000000',
                sequence_number_range: {
                  starting_sequence_number: '12345678901234567890123456789012345678901234567890123456'}}]}}])
    }

    client.get_shard_iterator { {shard_iterator: 'SHARD_ITERATOR'} }

    client.get_records {
      [{
        records: [],
        next_shard_iterator: 'NEXT_SHARD_ITERATOR'
      }]
    }

    stub(Aws::Kinesis::Client).new do |options|
      assert_equal(nil, options[:access_key_id])
      assert_equal(nil, options[:secret_access_key])
      assert_equal("us-east-1", options[:region])

      credentials = options[:credentials]
      assert_equal("default", credentials.profile_name)
      assert_equal("/home/scott/.aws/credentials", credentials.path)

      client
    end

    d = create_driver(<<-EOS)
      profile default
      credentials_path /home/scott/.aws/credentials
      stream_name test_stream
      region us-east-1
      tag test
    EOS

    d.run
  end

  def test_configure_with_shard_iterator_type
    d = create_driver(<<-EOS)
      #{CONFIG}
      shard_iterator_type AT_SEQUENCE_NUMBER
      shards {"shardId-000000000000":"12345678901234567890123456789012345678901234567890123456"}
    EOS

    assert_equal 'test_key_id', d.instance.aws_key_id
    assert_equal 'test_sec_key', d.instance.aws_sec_key
    assert_equal 'us-east-1', d.instance.region
    assert_equal 'test_stream', d.instance.stream_name
    assert_equal 'test', d.instance.tag
    assert_equal 'AT_SEQUENCE_NUMBER', d.instance.shard_iterator_type
    assert_equal({"shardId-000000000000" => "12345678901234567890123456789012345678901234567890123456"}, d.instance.shards)
  end

  def test_configure_with_invalid_shard_iterator_type
    assert_raise(Fluent::ConfigError) {
      create_driver(<<-EOS)
        #{CONFIG}
        shard_iterator_type xLATEST
      EOS
    }
  end

  def test_configure_with_shards
    d = create_driver(<<-EOS)
      #{CONFIG}
      shards {"shardId-000000000000":"12345678901234567890123456789012345678901234567890123456"}
      shard_iterator_type AT_SEQUENCE_NUMBER
    EOS

    assert_equal 'test_key_id', d.instance.aws_key_id
    assert_equal 'test_sec_key', d.instance.aws_sec_key
    assert_equal 'us-east-1', d.instance.region
    assert_equal 'test_stream', d.instance.stream_name
    assert_equal 'test', d.instance.tag
    assert_equal 'AT_SEQUENCE_NUMBER', d.instance.shard_iterator_type
    assert_equal({"shardId-000000000000"=>"12345678901234567890123456789012345678901234567890123456"}, d.instance.shards)
  end

  def test_fetch
    d = create_driver(<<-EOS)
      #{CONFIG}
      shard_iterator_type AT_SEQUENCE_NUMBER
    EOS

    client = create_mock_clinet

    client.describe_stream(stream_name: 'test_stream') {
      to_stub([
        { stream_description: {
            shards: [
              {
                shard_id: 'shardId-000000000000',
                sequence_number_range: {
                  starting_sequence_number: '12345678901234567890123456789012345678901234567890123456'}}]}}])
    }

    client.get_shard_iterator(
      stream_name: 'test_stream',
      shard_id: 'shardId-000000000000',
      shard_iterator_type: 'AT_SEQUENCE_NUMBER',
      starting_sequence_number: '12345678901234567890123456789012345678901234567890123456',
    ) { {shard_iterator: 'SHARD_ITERATOR'} }

    client.get_records(shard_iterator: 'SHARD_ITERATOR') {
      [{
        records: [
          {data: 'data1', sequence_number: 'SEQUENCE_NUMBER', partition_key: 'PARTITION_KEY'},
          {data: 'data2', sequence_number: 'SEQUENCE_NUMBER', partition_key: 'PARTITION_KEY'},
        ],
        next_shard_iterator: 'NEXT_SHARD_ITERATOR'
      }]
    }

    Timecop.freeze(Time.parse('2011-01-02T13:14:15Z')) do
      d.run
    end

    assert_equal d.emits, [
      ["test", 1293974055, {data: "data1", sequence_number: "SEQUENCE_NUMBER", partition_key: "PARTITION_KEY", shard_id: "shardId-000000000000"}],
      ["test", 1293974055, {data: "data2", sequence_number: "SEQUENCE_NUMBER", partition_key: "PARTITION_KEY", shard_id: "shardId-000000000000"}],
    ]
  end

  def test_fetch_json
    d = create_driver(<<-EOS)
      #{CONFIG}
      shard_iterator_type AT_SEQUENCE_NUMBER
      json_data true
    EOS

    client = create_mock_clinet

    client.describe_stream(stream_name: 'test_stream') {
      to_stub([
        { stream_description: {
            shards: [
              {
                shard_id: 'shardId-000000000000',
                sequence_number_range: {
                  starting_sequence_number: '12345678901234567890123456789012345678901234567890123456'}}]}}])
    }

    client.get_shard_iterator(
      stream_name: 'test_stream',
      shard_id: 'shardId-000000000000',
      shard_iterator_type: 'AT_SEQUENCE_NUMBER',
      starting_sequence_number: '12345678901234567890123456789012345678901234567890123456',
    ) { {shard_iterator: 'SHARD_ITERATOR'} }

    client.get_records(shard_iterator: 'SHARD_ITERATOR') {
      [{
        records: [
          {data: JSON.dump(data1_key1: 'val1', data1_key2: 'val2'), sequence_number: 'SEQUENCE_NUMBER', partition_key: 'PARTITION_KEY'},
          {data: JSON.dump(data2_key1: 'val1', data2_key2: 'val2'), sequence_number: 'SEQUENCE_NUMBER', partition_key: 'PARTITION_KEY'},
        ],
        next_shard_iterator: 'NEXT_SHARD_ITERATOR'
      }]
    }

    Timecop.freeze(Time.parse('2011-01-02T13:14:15Z')) do
      d.run
    end

    assert_equal d.emits, [
      ["test", 1293974055, {"data1_key1" => 'val1', "data1_key2" => 'val2', sequence_number: "SEQUENCE_NUMBER", partition_key: "PARTITION_KEY", shard_id: "shardId-000000000000"}],
      ["test", 1293974055, {"data2_key1" => 'val1', "data2_key2" => 'val2', sequence_number: "SEQUENCE_NUMBER", partition_key: "PARTITION_KEY", shard_id: "shardId-000000000000"}],
    ]
  end

  def test_tag_placeholder
    d = create_driver(<<-EOS)
      aws_key_id test_key_id
      aws_sec_key test_sec_key
      region us-east-1
      stream_name test_stream
      tag test.${foo}.${bar}
      shard_iterator_type AT_SEQUENCE_NUMBER
      json_data true
    EOS

    client = create_mock_clinet

    client.describe_stream(stream_name: 'test_stream') {
      to_stub([
        { stream_description: {
            shards: [
              {
                shard_id: 'shardId-000000000000',
                sequence_number_range: {
                  starting_sequence_number: '12345678901234567890123456789012345678901234567890123456'}}]}}])
    }

    client.get_shard_iterator(
      stream_name: 'test_stream',
      shard_id: 'shardId-000000000000',
      shard_iterator_type: 'AT_SEQUENCE_NUMBER',
      starting_sequence_number: '12345678901234567890123456789012345678901234567890123456',
    ) { {shard_iterator: 'SHARD_ITERATOR'} }

    client.get_records(shard_iterator: 'SHARD_ITERATOR') {
      [{
        records: [
          {data: JSON.dump(foo: 'FOO1', bar: 'BAR1'), sequence_number: 'SEQUENCE_NUMBER', partition_key: 'PARTITION_KEY'},
          {data: JSON.dump(foo: 'FOO2', bar: 'BAR2'), sequence_number: 'SEQUENCE_NUMBER', partition_key: 'PARTITION_KEY'},
        ],
        next_shard_iterator: 'NEXT_SHARD_ITERATOR'
      }]
    }

    Timecop.freeze(Time.parse('2011-01-02T13:14:15Z')) do
      d.run
    end

    assert_equal d.emits, [
      ["test.FOO1.BAR1", 1293974055, {"foo" => 'FOO1', "bar" => 'BAR1', sequence_number: "SEQUENCE_NUMBER", partition_key: "PARTITION_KEY", shard_id: "shardId-000000000000"}],
      ["test.FOO2.BAR2", 1293974055, {"foo" => 'FOO2', "bar" => 'BAR2', sequence_number: "SEQUENCE_NUMBER", partition_key: "PARTITION_KEY", shard_id: "shardId-000000000000"}],
    ]
  end
end
