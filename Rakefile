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

require "bundler/gem_tasks"

require 'rake/testtask'

task default: [:test]
Rake::TestTask.new do |test|
  test.libs << 'lib' << 'test'
  test.test_files = FileList['test/**/test_*.rb']
  test.options = '-v'
end

load 'kinesis_producer/tasks/binary.rake'
Rake::Task[:build].enhance [:binaries]
Rake::Task[:test].enhance [:binaries]

load 'benchmark/task.rake'
