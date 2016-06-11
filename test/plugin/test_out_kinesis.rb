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

require 'test/unit'
require 'test/unit/rr'
require 'fluent/load'
require 'fluent/test'
require 'fluent/plugin/out_kinesis'

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

  CONFIG_YAJL= CONFIG + %[
    use_yajl true
  ]

  CONFIG_WITH_COMPRESSION = CONFIG + %[
    zlib_compression true
  ]

  CONFIG_YAJL_WITH_COMPRESSION = CONFIG_YAJL + %[
    zlib_compression true
  ]

  def create_driver(conf = CONFIG, tag='test')
    Fluent::Test::BufferedOutputTestDriver
      .new(FluentPluginKinesis::OutputFilter, tag).configure(conf)
  end

  def create_mock_client
    client = mock(Object.new)
    require 'fluent_plugin_kinesis/version'
    opts = {
      user_agent_suffix: "fluent-plugin-kinesis-output-filter/#{FluentPluginKinesis::VERSION}",
      region:            "us-east-1",
      access_key_id:     "test_key_id",
      secret_access_key: "test_sec_key",
    }
    mock(Aws::Kinesis::Client).new(opts) { client }
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

  def test_configure_with_credentials
    d = create_driver(<<-EOS)
      profile default
      credentials_path /home/scott/.aws/credentials
      stream_name test_stream
      region us-east-1
      partition_key test_partition_key
    EOS

    assert_equal 'default', d.instance.profile
    assert_equal '/home/scott/.aws/credentials', d.instance.credentials_path
    assert_equal 'test_stream', d.instance.stream_name
    assert_equal 'us-east-1', d.instance.region
    assert_equal 'test_partition_key', d.instance.partition_key
  end

  def test_load_client
    client = stub(Object.new)
    client.describe_stream
    client.put_records { {} }

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
    client.describe_stream
    client.put_records { {} }

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
      partition_key test_partition_key
    EOS

    d.run
  end

  def test_load_client_with_role_arn
    client = stub(Object.new)
    client.describe_stream
    client.put_records { {} }

    stub(Aws::AssumeRoleCredentials).new do |options|
      assert_equal("arn:aws:iam::001234567890:role/my-role", options[:role_arn])
      assert_equal("aws-fluent-plugin-kinesis", options[:role_session_name])
      assert_equal("my_external_id", options[:external_id])
      assert_equal(3600, options[:duration_seconds])
      "sts_credentials"
    end

    stub(Aws::Kinesis::Client).new do |options|
      assert_equal("sts_credentials", options[:credentials])
      client
    end

    d = create_driver(<<-EOS)
      role_arn arn:aws:iam::001234567890:role/my-role
      external_id my_external_id
      stream_name test_stream
      region us-east-1
      partition_key test_partition_key
    EOS
    d.run
  end

  def test_configure_with_more_options

    conf = %[
      stream_name test_stream
      region us-east-1
      ensure_stream_connection false
      http_proxy http://proxy:3333/
      partition_key test_partition_key
      partition_key_expr record
      explicit_hash_key test_hash_key
      explicit_hash_key_expr record
      order_events true
      use_yajl true
    ]
    d = create_driver(conf)
    assert_equal 'test_stream', d.instance.stream_name
    assert_equal 'us-east-1', d.instance.region
    assert_equal false, d.instance.ensure_stream_connection
    assert_equal 'http://proxy:3333/', d.instance.http_proxy
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
    assert_equal true, d.instance.use_yajl
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


  data("json"=>CONFIG, "yajl"=>CONFIG_YAJL)
  def test_format_without_compression(config)

    d = create_driver(config)

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

  data("json"=>CONFIG_WITH_COMPRESSION, "yajl"=>CONFIG_YAJL_WITH_COMPRESSION)
  def test_format_with_compression(config)

    d = create_driver(config)

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
          data: Zlib::Deflate.deflate(data1.to_json),
          partition_key: 'key1'
        },
        {
          data: Zlib::Deflate.deflate(data2.to_json),
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

  def test_multibyte_with_yajl_without_compression

    d = create_driver(CONFIG_YAJL)

    data1 = {"test_partition_key"=>"key1","a"=>"\xE3\x82\xA4\xE3\x83\xB3\xE3\x82\xB9\xE3\x83\x88\xE3\x83\xBC\xE3\x83\xAB","time"=>"2011-01-02T13:14:15Z","tag"=>"test"}
    json = Yajl.dump(data1)
    data1["a"].force_encoding("ASCII-8BIT")

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    d.emit(data1, time)

    d.expect_format({
      'data' => json,
      'partition_key' => 'key1' }.to_msgpack
    )

    client = create_mock_client
    client.describe_stream(stream_name: 'test_stream')
    client.put_records(
      stream_name: 'test_stream',
      records: [
        {
          data: json,
          partition_key: 'key1'
        }
      ]
    ) { {} }

    d.run
  end

  def test_multibyte_with_yajl_with_compression

    d = create_driver(CONFIG_YAJL_WITH_COMPRESSION)

    data1 = {"test_partition_key"=>"key1","a"=>"\xE3\x82\xA4\xE3\x83\xB3\xE3\x82\xB9\xE3\x83\x88\xE3\x83\xBC\xE3\x83\xAB","time"=>"2011-01-02T13:14:15Z","tag"=>"test"}
    json = Yajl.dump(data1)
    data1["a"].force_encoding("ASCII-8BIT")

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    d.emit(data1, time)

    d.expect_format({
      'data' => json,
      'partition_key' => 'key1' }.to_msgpack
    )

    client = create_mock_client
    client.describe_stream(stream_name: 'test_stream')
    client.put_records(
      stream_name: 'test_stream',
      records: [
        {
          data: Zlib::Deflate.deflate(json),
          partition_key: 'key1'
        }
      ]
    ) { {} }

    d.run
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

    # PUT_RECORD_MAX_DATA_SIZE = 1024*1024 is way too big, try something smaller (10), just to verify the logic not the actual value
    original_put_record_max_data_size = d.instance.class.send(:remove_const, :PUT_RECORD_MAX_DATA_SIZE) if d.instance.class.const_defined?(:PUT_RECORD_MAX_DATA_SIZE)
    d.instance.class.const_set(:PUT_RECORD_MAX_DATA_SIZE, 10)

    string = ''
    (1..5).each{ string = string + '1' }
    assert_equal(
      false,
      d.instance.send(:record_exceeds_max_size?,string)
    )

    string = ''
    (1..10).each{ string = string + '1' }
    assert_equal(
      false,
      d.instance.send(:record_exceeds_max_size?,string)
    )

    string = ''
    (1..11).each{ string = string + '1' }
    assert_equal(
      true,
      d.instance.send(:record_exceeds_max_size?,string)
    )

    # reset the constant
    d.instance.class.send(:remove_const, :PUT_RECORD_MAX_DATA_SIZE)
    d.instance.class.const_set(:PUT_RECORD_MAX_DATA_SIZE, original_put_record_max_data_size)
  end

  def test_build_records_array_to_put
    d = create_driver

    # PUT_RECORDS_MAX_DATA_SIZE = 1024*1024*5 is way too big, try something smaller (100), just to verify the logic not the actual value
    original_put_records_max_data_size = d.instance.class.send(:remove_const, :PUT_RECORDS_MAX_DATA_SIZE) if d.instance.class.const_defined?(:PUT_RECORDS_MAX_DATA_SIZE)
    d.instance.class.const_set(:PUT_RECORDS_MAX_DATA_SIZE, 100)

    # PUT_RECORDS_MAX_COUNT = 500 is way too big, try something smaller (10), just to verify the logic not the actual value
    original_put_records_max_count = d.instance.class.send(:remove_const, :PUT_RECORDS_MAX_COUNT) if d.instance.class.const_defined?(:PUT_RECORDS_MAX_COUNT)
    d.instance.class.const_set(:PUT_RECORDS_MAX_COUNT, 10)

    data_list = []
    (0..10).each do |n|
      data_list.push({data: '1', partition_key: '0'})
    end
    result = d.instance.send(:build_records_array_to_put,data_list)
    assert_equal(2,result.length)
    assert_equal(10,result[0].length)
    assert_equal(1,result[1].length)

    data_list = []
    (0..24).each do
      data_list.push({data: '1', partition_key: '0'})
    end
    result = d.instance.send(:build_records_array_to_put,data_list)
    assert_equal(3,result.length)
    assert_equal(10,result[0].length)
    assert_equal(10,result[1].length)
    assert_equal(5,result[2].length)

    data_list = []
    (0..20).each do
      data_list.push({data: '0123456789', partition_key: '1'})
    end
    # Should return 3 lists: 9*11 + 9*11 + 3*11
    result = d.instance.send(:build_records_array_to_put,data_list)
    assert_equal(3,result.length)
    assert_equal(9,result[0].length)
    assert_operator(
      100, :>,
      result[0].reduce(0){|sum,i| sum + i[:data].length + i[:partition_key].length}
    )
    assert_equal(9,result[1].length)
    assert_operator(
      100, :>,
      result[1].reduce(0){|sum,i| sum + i[:data].length + i[:partition_key].length}
    )
    assert_equal(3,result[2].length)
    assert_operator(
      100, :>,
      result[2].reduce(0){|sum,i| sum + i[:data].length + i[:partition_key].length}
    )

    # reset the constants
    d.instance.class.send(:remove_const, :PUT_RECORDS_MAX_DATA_SIZE)
    d.instance.class.send(:remove_const, :PUT_RECORDS_MAX_COUNT)
    d.instance.class.const_set(:PUT_RECORDS_MAX_DATA_SIZE, original_put_records_max_data_size)
    d.instance.class.const_set(:PUT_RECORDS_MAX_COUNT, original_put_records_max_count)
  end

  def test_build_empty_array_to_put
    d = create_driver
    data_list = []
    result = d.instance.send(:build_records_array_to_put,data_list)
    assert_equal(0, result.length, 'Should return empty array if there is no record')
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
