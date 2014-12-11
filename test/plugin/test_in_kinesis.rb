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
end
