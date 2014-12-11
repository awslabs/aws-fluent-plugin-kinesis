require 'helper'

class KinesisOutputTest < Test::Unit::TestCase
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
    d = create_driver
    assert_equal 'test_key_id', d.instance.aws_key_id
    assert_equal 'test_sec_key', d.instance.aws_sec_key
    assert_equal 'us-east-1', d.instance.region
    assert_equal 'test_stream', d.instance.stream_name
    assert_equal 'test', d.instance.tag
  end

  def test_configure_with_shard_iterator_type
    d = create_driver(<<-EOS)
      #{CONFIG}
      shard_iterator_type AT_SEQUENCE_NUMBER
      sequence_number 12345678901234567890123456789012345678901234567890123456
    EOS

    assert_equal 'test_key_id', d.instance.aws_key_id
    assert_equal 'test_sec_key', d.instance.aws_sec_key
    assert_equal 'us-east-1', d.instance.region
    assert_equal 'test_stream', d.instance.stream_name
    assert_equal 'test', d.instance.tag
    assert_equal 'AT_SEQUENCE_NUMBER', d.instance.shard_iterator_type
    assert_equal '12345678901234567890123456789012345678901234567890123456', d.instance.sequence_number
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
          {data: Base64.strict_encode64('data1'), sequence_number: 'SEQUENCE_NUMBER', partition_key: 'PARTITION_KEY'},
          {data: Base64.strict_encode64('data2'), sequence_number: 'SEQUENCE_NUMBER', partition_key: 'PARTITION_KEY'},
        ],
        next_shard_iterator: 'NEXT_SHARD_ITERATOR'
      }]
    }

    Timecop.freeze(Time.parse('"2011-01-02T13:14:15Z')) do
      d.run
    end

    assert_equal d.emits, [
      ["test", 1293974055, {data: "data1", sequence_number: "SEQUENCE_NUMBER", partition_key: "PARTITION_KEY", shard_id: "shardId-000000000000"}],
      ["test", 1293974055, {data: "data2", sequence_number: "SEQUENCE_NUMBER", partition_key: "PARTITION_KEY", shard_id: "shardId-000000000000"}],
    ]
  end
end
