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
require 'fluent/plugin/kinesis_helper/api'
require 'aws-sdk'

class KinesisHelperAPITest < Test::Unit::TestCase
  class Mock
    include Fluent::KinesisHelper::API

    attr_accessor :retries_on_batch_request, :reset_backoff_if_success
    attr_accessor :failed_scenario, :request_series

    def initialize
      @retries_on_batch_request = 3
      @reset_backoff_if_success = true
      @failed_scenario = [].to_enum
      @request_series = []
    end

    def request_type
      :firehose
    end

    def batch_request(batch)
      request_series.push(batch.size)
      failed = failed_num
      make_response(batch.size - failed, failed)
    end

    def failed_num
      failed_scenario.next
    end

    def make_response(success_num, failed_num)
      responses = []
      success_num.times { responses << success_response }
      failed_num.times  { responses << failed_response }
      Aws::Firehose::Types::PutRecordBatchOutput.new(
        failed_put_count: failed_num,
        request_responses: responses,
      )
    end

    def success_response
      Aws::Firehose::Types::PutRecordBatchResponseEntry.new(
        record_id: "49543463076548007577105092703039560359975228518395019266",
      )
    end

    def failed_response
      Aws::Firehose::Types::PutRecordBatchResponseEntry.new(
        error_code: "ServiceUnavailableException",
        error_message: "Some message",
      )
    end

    def log
      @log ||= Fluent::Test::TestLogger.new()
    end

    def truncate(msg)
      msg
    end
  end

  def setup
    @object = Mock.new
    @backoff = mock()
    @backoff.stubs(:next).returns(0)
    @backoff.stubs(:reset)
  end

  data(
    'split_by_count'            => [Array.new(11, {data:'a'*1}),  [10,1]],
    'split_by_size'             => [Array.new(11, {data:'a'*10}), [2,2,2,2,2,1]],
    'split_by_size_with_space'  => [Array.new(11, {data:'a'*6}),  [3,3,3,2]],
  )
  def test_batch_by_limit(data)
    records, expected = data
    result = @object.send(:batch_by_limit, records, 10, 20)
    assert_equal expected, result.map(&:size)
  end

  data(
    'no_failed_completed'     => [[0,0,0,0], [5],       true],
    '1_failed_completed'      => [[1,0,0,0], [5,1],     true],
    'some_failed_completed'   => [[3,2,1,0], [5,3,2,1], true],
    'some_failed_incompleted' => [[4,3,2,1], [5,4,3,2], false],
    'all_failed_incompleted'  => [[5,5,5,5], [5,5,5,5], false],
  )
  def test_batch_request_with_retry(data)
    failed_scenario, expected, completed = data
    batch = Array.new(5, {})
    @object.failed_scenario = failed_scenario.to_enum
    @object.expects(:give_up_retries).times(completed ? 0 : 1)
    @object.send(:batch_request_with_retry, batch, backoff: @backoff)
    assert_equal expected, @object.request_series
  end

  data(
    'reset_everytime' => [true,  [4,3,2,1], 3],
    'disable_reset'   => [false, [4,3,2,1], 0],
    'never_reset'     => [true,  [5,5,5,5], 0],
  )
  def test_reset_backoff(data)
    reset_backoff, failed_scenario, expected = data
    batch = Array.new(5, {})
    @object.reset_backoff_if_success = reset_backoff
    @object.failed_scenario = failed_scenario.to_enum
    @backoff.expects(:reset).times(expected)
    @object.send(:batch_request_with_retry, batch, backoff: @backoff)
  end
end
