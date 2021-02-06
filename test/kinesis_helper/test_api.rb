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
require 'fluent/plugin/kinesis_helper/api'
require 'benchmark'

class KinesisHelperAPITest < Test::Unit::TestCase
  class Mock
    include Fluent::Plugin::KinesisHelper::API
    include Fluent::Plugin::KinesisHelper::API::BatchRequest

    attr_accessor :retries_on_batch_request, :reset_backoff_if_success
    attr_accessor :failed_scenario, :request_series
    attr_accessor :batch_request_max_count, :batch_request_max_size
    attr_accessor :num_errors, :drop_failed_records_after_batch_request_retries, :monitor_num_of_batch_request_retries

    def initialize
      @retries_on_batch_request = 3
      @reset_backoff_if_success = true
      @failed_scenario = [].to_enum
      @request_series = []
      @num_errors = 0
      @drop_failed_records_after_batch_request_retries = true
      @monitor_num_of_batch_request_retries = false
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
    'split_by_count'            => [Array.new(11, ['a'*1]),  [10,1]],
    'split_by_size'             => [Array.new(11, ['a'*10]), [2,2,2,2,2,1]],
    'split_by_size_with_space'  => [Array.new(11, ['a'*6]),  [3,3,3,2]],
  )
  def test_split_to_batches(data)
    records, expected = data
    result = []
    @object.batch_request_max_count = 10
    @object.batch_request_max_size = 20
    @object.send(:split_to_batches, records){|batch, size| result << batch }
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
    @object.send(:batch_request_with_retry, batch, backoff: @backoff) { |batch| @object.batch_request(batch) }
    assert_equal expected, @object.request_series
  end

  def test_reliable_sleep
    time = Benchmark.realtime do
      t = Thread.new { @object.send(:reliable_sleep, 0.2) }
      sleep 0.1
      t.run
      t.join
    end
    assert_operator time, :>, 0.15
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
    @object.send(:batch_request_with_retry, batch, backoff: @backoff) { |batch| @object.batch_request(batch) }
  end

  data(
    'enabled_no_failed_completed'      => [true,  [0,0,0,0], 0],
    'enabled_some_failed_completed'    => [true,  [3,2,1,0], 0],
    'enabled_some_failed_incompleted'  => [true,  [4,3,2,1], 1],
    'enabled_all_failed_incompleted'   => [true,  [5,5,5,5], 1],
    'disabled_no_failed_completed'     => [false, [0,0,0,0], 0],
    'disabled_some_failed_completed'   => [false, [3,2,1,0], 0],
    'disabled_some_failed_incompleted' => [false, [4,3,2,1], 1],
    'disabled_all_failed_incompleted'  => [false, [5,5,5,5], 1],
  )
  def test_drop_failed_records_after_batch_request_retries(data)
    param, failed_scenario, expected = data
    batch = Array.new(5, {})
    @object.drop_failed_records_after_batch_request_retries = param
    @object.failed_scenario = failed_scenario.to_enum
    if !param && expected > 0
      e = assert_raises Aws::Firehose::Errors::ServiceUnavailableException do
        @object.send(:batch_request_with_retry, batch, backoff: @backoff) { |batch| @object.batch_request(batch) }
      end
      assert_equal @object.failed_response.error_message, e.message
    else
      @object.send(:batch_request_with_retry, batch, backoff: @backoff) { |batch| @object.batch_request(batch) }
      assert_equal expected, @object.num_errors
    end
  end

  data(
    'disabled_no_failed_completed'     => [false, [0,0,0,0], 0],
    'disabled_some_failed_completed'   => [false, [3,2,1,0], 0],
    'disabled_some_failed_incompleted' => [false, [4,3,2,1], 1],
    'disabled_all_failed_incompleted'  => [false, [5,5,5,5], 1],
    'enabled_no_failed_completed'      => [true,  [0,0,0,0], 0],
    'enabled_some_failed_completed'    => [true,  [3,2,1,0], 3],
    'enabled_some_failed_incompleted'  => [true,  [4,3,2,1], 4],
    'enabled_all_failed_incompleted'   => [true,  [5,5,5,5], 4],
  )
  def test_monitor_num_of_batch_request_retries(data)
    param, failed_scenario, expected = data
    batch = Array.new(5, {})
    @object.monitor_num_of_batch_request_retries = param
    @object.failed_scenario = failed_scenario.to_enum
    @object.send(:batch_request_with_retry, batch, backoff: @backoff) { |batch| @object.batch_request(batch) }
    assert_equal expected, @object.num_errors
  end
end
