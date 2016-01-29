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
require 'fluent/plugin/kinesis_helper/format'

class KinesisHelperFormatTest < Test::Unit::TestCase
  class Mock
    include Fluent::KinesisHelper::Format

    attr_accessor :log_truncate_max_size

    def initialize
      @log_truncate_max_size = 0
    end

    def log
      @log ||= Fluent::Test::TestLogger.new
    end

    def convert_format(tag, time, record)
      { data: record.to_json }
    end
  end

  def setup
    @object = Mock.new
  end

  data(
    'valid'   => [{}, {data: "{}"}],
    'invalid' => [[], nil],
  )
  def test_convert_record_validation(data)
    record, expected = data
    result = @object.send(:convert_record, '', '', record)
    assert_equal expected, result
    assert_equal result.nil? ? 1 : 0, @object.log.logs.size
  end

  data(
    'not_exceeded' => [{"a"=>"a"*(1024*1024-'{"a":""}'.size)},   {data: '{"a":"'+"a"*(1024*1024-'{"a":""}'.size)+'"}'}],
    'exceeded'     => [{"a"=>"a"*(1024*1024-'{"a":""}'.size+1)}, nil],
  )
  def test_convert_record_max_record_size(data)
    record, expected = data
    result = @object.send(:convert_record, '', '', record)
    assert_equal expected, result
    assert_equal result.nil? ? 1 : 0, @object.log.logs.size
  end

  data(
    '1'     => [1,   "1"],
    '5'     => [5,   "12345"],
    '100'   => [100, "123456789"],
  )
  def test_truncate_max_size(data)
    max_size, expected = data
    @object.log_truncate_max_size = max_size
    result = @object.send(:truncate, "123456789")
    assert_equal expected, result
  end
end
