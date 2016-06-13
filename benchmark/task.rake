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

require_relative '../test/dummy_server'

task :benchmark do
  server = DummyServer.start
  conf = profile_conf(ENV["TYPE"] || 'streams', ENV["RATE"] || 1000, server)
  pid = spawn("bundle exec fluentd -i '#{conf}' -c benchmark/dummy.conf")
  sleep 10
  Process.kill("TERM", pid)
  Process.wait
  puts "Results: requets: #{server.requests.size}, raw_records: #{server.raw_records.size}, records: #{server.records.size}"
  server.shutdown
end

def profile_conf(type, rate, server)
  additional_conf = case type
                  when 'streams', 'firehose'
                    <<-EOS
  endpoint https://localhost:#{server.port}
  ssl_verify_peer false
                    EOS
                  when 'producer'
                    <<-EOS
  debug true
  <kinesis_producer>
    custom_endpoint localhost
    port #{server.port}
    verify_certificate false
    record_max_buffered_time 1000
    log_level error
  </kinesis_producer>
                    EOS
                  end

  conf = <<-EOS
<source>
  @type dummy
  tag dummy
  rate #{rate}
</source>

<match dummy>
  @type kinesis_#{type}
  flush_interval 1
  buffer_chunk_limit 1m
  try_flush_interval 0.1
  queued_chunk_flush_interval 0.01
  @log_level debug

  num_threads 100

  region ap-northeast-1
  stream_name fluent-plugin-test

#{additional_conf}
</match>
  EOS
  conf
end
