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
require 'fluent/plugin/kinesis_helper/error'

class KinesisHelperFormatTest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @object.extend(Fluent::KinesisHelper::Format)
    class << @object
      define_method :log do
        @log ||= Fluent::Test::TestLogger.new
      end
      define_method :convert_format do |tag, time, record|
        { data: record.to_json }
      end
    end
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
    if result.nil?
      assert @object.log.logs.first.size < 1024*1024
    end
  end
end
