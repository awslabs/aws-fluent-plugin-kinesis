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

require_relative '../test/helper'
require 'fluent/plugin/out_kinesis_streams'
require 'fluent/plugin/out_kinesis_streams_aggregated'
require 'fluent/plugin/out_kinesis_firehose'
require 'benchmark'
require 'net/empty_port'

namespace :benchmark do
  task :local do
    KinesisBenchmark.new.run
  end
  task :remote do
    KinesisBenchmark.new(false).run
  end
end

class KinesisBenchmark
  def initialize(local = true)
    @local = local
    Fluent::Test.setup
  end

  def run
    setup
    benchmark(ENV['SIZE'] || 100, ENV['COUNT'] || 10000)
    teardown
  end

  def setup
    return if not @local
    @port = Net::EmptyPort.empty_port
    @server_pid = fork do
      Process.setsid
      server = DummyServer.start(port: @port)
      Signal.trap("TERM") do
        server.shutdown
      end
      server.thread.join
    end
    Net::EmptyPort.wait(@port, 3)
  end

  def teardown
    return if not @local
    Process.kill "TERM", @server_pid
    Process.waitpid @server_pid
  end

  def default_config
    conf = %[
      log_level error
      region ap-northeast-1
      data_key a
    ]
    if @local
      conf += %[
      endpoint https://localhost:#{@port}
      ssl_verify_peer false
      ]
    end
    conf
  end

  def create_driver(type, conf = default_config)
    klass = case type
            when :streams
              Fluent::Plugin::KinesisStreamsOutput
            when :streams_aggregated
              Fluent::Plugin::KinesisStreamsAggregatedOutput
            when :firehose
              Fluent::Plugin::KinesisFirehoseOutput
            end
    conf += case type
            when :streams, :streams_aggregated
              "stream_name fluent-plugin-test"
            when :firehose
              "delivery_stream_name fluent-plugin-test"
            end

    Fluent::Test::Driver::Output.new(klass) do
    end.configure(conf)
  end

  def benchmark(size, count)
    record = {"a"=>"a"*size}
    Benchmark.bmbm(20) do |x|
      [:streams_aggregated, :streams, :firehose].each do |type|
        x.report(type)  { driver_run(create_driver(type),  count.times.map{|i|record}) }
      end
    end
  end
end
