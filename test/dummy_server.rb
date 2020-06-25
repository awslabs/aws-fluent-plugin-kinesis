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

require 'webrick/https'
require 'net/empty_port'
require 'base64'
require 'fluent/plugin/kinesis_helper/aggregator'

module WEBrick
  class HTTPResponse
    def create_error_page
      @body = '{}'
    end
  end
end

class DummyServer
  class << self
    def start(seed: 0, port: nil)
      @server ||= DummyServer.new(seed: seed, port: port).start
    end
  end

  def initialize(seed: 0, port: nil)
    @random = Random.new(seed)
    @random_500 = Random.new(seed)
    @random_error = false
    @requests = []
    @accepted_records = []
    @failed_count = 0
    @error_count = 0
    @server, @port = init_server(port)
    @aggregator = Fluent::Plugin::KinesisHelper::Aggregator.new
    @recording = true
  end

  def start
    trap 'INT' do @server.shutdown end
    @thread = Thread.new do
      @server.start
    end
    Net::EmptyPort.wait(@port, 3)
    self
  end

  def stop_recording
    @recording = false
  end

  def thread
    @thread
  end

  def clear
    @random_error = false
    @requests = []
    @accepted_records = []
    @failed_count = 0
    @error_count = 0
    @recording = true
  end

  def shutdown
    clear
    @server.shutdown
  end

  def port
    @port
  end

  def requests
    @requests
  end

  def count_per_requests
    @requests.map{|req|JSON.parse(req.body)['Records'].size}
  end

  def size_per_requests
    @requests.map{|req|
      JSON.parse(req.body)['Records'].map{|r|
        (r['Data'] ? Base64.decode64(r['Data']).size : 0)+(r['PartitionKey'] ? r['PartitionKey'].size : 0)
      }.inject(:+) || 0
    }
  end

  def raw_records
    @accepted_records
  end

  def records
    flatten_records(@accepted_records)
  end

  def detailed_records
    flatten_records(@accepted_records, detailed: true)
  end

  def failed_count
    @failed_count
  end

  def error_count
    @error_count
  end

  def aggregated_count
    aggregated_count = 0
    @accepted_records.flat_map do |record|
      data = Base64.decode64(record[:record]['Data'])
      if data[0,4] == ['F3899AC2'].pack('H*')
        aggregated_count += 1
      end
    end
    aggregated_count
  end

  def enable_random_error
    @random_error = true
  end

  def disable_random_error
    @random_error = false
  end

  private

  def recording?
    @recording
  end

  def init_server(port)
    port ||= Net::EmptyPort.empty_port
    server = suppress_stderr do
      WEBrick::HTTPServer.new(
        ServerName: 'localhost',
        Port: port,
        SSLEnable: true,
        SSLCertName: [%w[CN localhost]],
        Logger: WEBrick::Log.new('/dev/null'),
        AccessLog: [],
      )
    end
    server.mount_proc '/' do |req, res|
      @requests << req
      body = case req['X-Amz-Target']
             when 'Kinesis_20131202.DescribeStream'
               describe_stream_boby(req)
             when 'Kinesis_20131202.PutRecord'
               if random_error_500
                 @error_count += 1 if recording?
                 res.status = 500
                 {}
               elsif data_exceeded?(req)
                 res.status = 400
                 {}
               else
                 put_record_boby(req)
               end
             when 'Kinesis_20131202.PutRecords'
               if random_error_500
                 @error_count += 1 if recording?
                 res.status = 500
                 {}
               elsif batch_exceeded?(req, 500, 5*1024*1024)
                 res.status = 400
                 {}
               else
                 put_records_boby(req)
               end
             when 'Firehose_20150804.PutRecordBatch'
               if random_error_500
                 @error_count += 1 if recording?
                 res.status = 500
                 {}
               elsif batch_exceeded?(req, 500, 4*1024*1024)
                 res.status = 400
                 {}
               else
                 put_record_batch_boby(req)
               end
             else
               {}
             end
      res.body = body.to_json
    end
    [server, port]
  end

  def random_fail
    return false unless @random_error
    return true if failed_count == 0
    @random.rand >= 0.9
  end

  def random_error_500
    return false unless @random_error
    return true if error_count == 0
    @random_500.rand >= 0.9
  end

  def data_exceeded?(req)
    r = JSON.parse(req.body)
    data_size = Base64.decode64(r['Data']).size + (r['PartitionKey'] ? r['PartitionKey'].size : 0)
    data_size > 1024 * 1024
  end

  def describe_stream_boby(req)
    region = req.host.split('.')[1]
    body = JSON.parse(req.body)
    {
      "StreamDescription" => {
        "RetentionPeriodHours" => 24,
        "Shards" => [
          {
            "ShardId" => "shardId-000000000000",
            "HashKeyRange" => {
              "EndingHashKey" => "340282366920938463463374607431768211455",
              "StartingHashKey" => "0"
            },
            "SequenceNumberRange" => {
              "StartingSequenceNumber" => "49548874935757925426371487721002507564716130893618479106"
            }
          }
        ],
        "StreamARN" => "arn:aws:kinesis:#{region}:123456789012:#{body["StreamName"]}",
        "StreamName" => body["StreamName"],
        "StreamStatus" => "ACTIVE"
      }
    }
  end

  def put_record_boby(req)
    body = JSON.parse(req.body)
    record = {'Data' => body['Data'], 'PartitionKey' => body['PartitionKey']}
    @accepted_records << {:stream_name => body['StreamName'], :delivery_stream_name => body['DeliveryStreamName'], :record => record} if recording?
    {
      "SequenceNumber" => "21269319989653637946712965403778482177",
      "ShardId" => "shardId-000000000001"
    }
  end

  def batch_exceeded?(req, max_count, max_size)
    records = JSON.parse(req.body)['Records']
    count = records.size
    size = 0
    records.each do |r|
      data_size = Base64.decode64(r['Data']).size + (r['PartitionKey'] ? r['PartitionKey'].size : 0)
      if data_size > 1024*1024
        return true
      else
        size += data_size
      end
    end
    count > max_count or size > max_size
  end

  def put_records_boby(req)
    body = JSON.parse(req.body)
    failed_record_count = 0
    records = body['Records'].map do |record|
      if random_fail
        failed_record_count += 1
        {
          "ErrorCode" => "ProvisionedThroughputExceededException",
          "ErrorMessage" => "Rate exceeded for shard shardId-000000000001 in stream exampleStreamName under account 111111111111."
        }
      else
        @accepted_records << {:stream_name => body['StreamName'], :delivery_stream_name => body['DeliveryStreamName'], :record => record} if recording?
        {
          "SequenceNumber" => "49543463076548007577105092703039560359975228518395019266",
          "ShardId" => "shardId-000000000000"
        }
      end
    end
    @failed_count += failed_record_count if recording?
    {
      "FailedRecordCount" => failed_record_count,
      "Records" => records
    }
  end

  def put_record_batch_boby(req)
    body = JSON.parse(req.body)
    failed_record_count = 0
    records = body['Records'].map do |record|
      if random_fail
        failed_record_count += 1
        {
          "ErrorCode" => "ServiceUnavailableException",
          "ErrorMessage" => "Some message"
        }
      else
        @accepted_records << {:stream_name => body['StreamName'], :delivery_stream_name => body['DeliveryStreamName'], :record => record} if recording?
        {
          "RecordId" => "49543463076548007577105092703039560359975228518395019266",
        }
      end
    end
    @failed_count += failed_record_count if recording?
    {
      "FailedPutCount" => failed_record_count,
      "RequestResponses" => records
    }
  end

  def flatten_records(records, detailed: false)
    records.flat_map do |record|
      data = Base64.decode64(record[:record]['Data'])
      partition_key = record[:record]['PartitionKey']
      if @aggregator.aggregated?(data)
        agg_data = @aggregator.deaggregate(data)[0]
        if detailed
          {:stream_name => record[:stream_name], :delivery_stream_name => record[:delivery_stream_name], :data => agg_data, :partition_key => partition_key}
        else
          agg_data
        end
      else
        if detailed
          {:stream_name => record[:stream_name], :delivery_stream_name => record[:delivery_stream_name], :data => data, :partition_key => partition_key}
        else
          data
        end
      end
    end
  end

  def suppress_stderr
    begin
      original_stderr = $stderr.clone
      $stderr.reopen(File.new('/dev/null', 'w'))
      ret = yield
    ensure
      $stderr.reopen(original_stderr)
    end
    ret
  end
end
