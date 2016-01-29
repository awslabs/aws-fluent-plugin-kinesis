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

require 'fluent/plugin/kinesis_helper/api'

require 'test-unit'

class KinesisHelperAPITest < Test::Unit::TestCase
  def setup
    @object = Object.new
    @object.extend(Fluent::KinesisHelper::API)
  end

  data(
    'split_by_count' => [Array.new(11, {a:'a'*1}),  [10, 1]],
    'split_by_size'  => [Array.new(11, {a:'a'*10}), [10, 1]],
  )
  def test_batch_by_limit(data)
    records, expected = data
    result = @object.send(:batch_by_limit, records, 10, 100)
    assert_equal expected, result.map(&:size)
  end
end
