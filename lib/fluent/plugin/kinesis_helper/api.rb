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

require 'fluent_plugin_kinesis/version'
require 'fluent/configurable'
require 'benchmark'

module Fluent
  module Plugin
    module KinesisHelper
      module API
        MaxRecordSize = 1024 * 1024 # 1 MB

        module APIParams
          include Fluent::Configurable
          config_param :max_record_size, :integer, default: MaxRecordSize
        end

        def self.included(mod)
          mod.include APIParams
        end

        def configure(conf)
          super
          if @max_record_size > MaxRecordSize
            raise ConfigError, "max_record_size can't be grater than #{MaxRecordSize/1024} KB."
          end
        end

        module BatchRequest
          module BatchRequestParams
            include Fluent::Configurable
            config_param :retries_on_batch_request,                        :integer, default: 8
            config_param :reset_backoff_if_success,                        :bool,    default: true
            config_param :batch_request_max_count,                         :integer, default: nil
            config_param :batch_request_max_size,                          :integer, default: nil
            config_param :drop_failed_records_after_batch_request_retries, :bool,    default: true
            config_param :monitor_num_of_batch_request_retries,            :bool,    default: false
          end

          def self.included(mod)
            mod.include BatchRequestParams
          end

          def configure(conf)
            super
            if @batch_request_max_count.nil?
              @batch_request_max_count = self.class::BatchRequestLimitCount
            elsif @batch_request_max_count > self.class::BatchRequestLimitCount
              raise ConfigError, "batch_request_max_count can't be grater than #{self.class::BatchRequestLimitCount}."
            end
            if @batch_request_max_size.nil?
              @batch_request_max_size = self.class::BatchRequestLimitSize
            elsif @batch_request_max_size > self.class::BatchRequestLimitSize
              raise ConfigError, "batch_request_max_size can't be grater than #{self.class::BatchRequestLimitSize}."
            end
          end

          def size_of_values(record)
            record.compact.map(&:size).inject(:+) || 0
          end

          private

          def split_to_batches(records, &block)
            batch = []
            size = 0
            records.each do |record|
              record_size = size_of_values(record)
              if batch.size+1 > @batch_request_max_count or size+record_size > @batch_request_max_size
                yield(batch, size)
                batch = []
                size = 0
              end
              batch << record
              size += record_size
            end
            yield(batch, size) if batch.size > 0
          end

          def batch_request_with_retry(batch, retry_count=0, backoff: nil, &block)
            backoff ||= Backoff.new
            res = yield(batch)
            if failed_count(res) > 0
              failed_records = collect_failed_records(batch, res)
              if retry_count < @retries_on_batch_request
                backoff.reset if @reset_backoff_if_success and any_records_shipped?(res)
                wait_second = backoff.next
                msg = 'Retrying to request batch. Retry count: %3d, Retry records: %3d, Wait seconds %3.2f' % [retry_count+1, failed_records.size, wait_second]
                log.warn(truncate msg)
                # Increment num_errors to monitor batch request retries from "monitor_agent" or "fluent-plugin-prometheus"
                increment_num_errors if @monitor_num_of_batch_request_retries
                reliable_sleep(wait_second)
                batch_request_with_retry(retry_records(failed_records), retry_count+1, backoff: backoff, &block)
              else
                give_up_retries(failed_records)
              end
            end
          end

          # Sleep seems to not sleep as long as we ask it, our guess is that something wakes up the thread,
          # so we keep on going to sleep if that happens.
          # TODO: find out who is causing the sleep to be too short and try to make them stop it instead
          def reliable_sleep(wait_second)
            loop do
              actual = Benchmark.realtime { sleep(wait_second) }
              break if actual >= wait_second
              log.error("#{Thread.current.object_id} sleep failed expected #{wait_second} but slept #{actual}")
              wait_second -= actual
            end
          end

          def any_records_shipped?(res)
            results(res).size > failed_count(res)
          end

          def collect_failed_records(records, res)
            failed_records = []
            results(res).each_with_index do |record, index|
              next unless record[:error_code]
              original = case request_type
                         when :streams, :firehose; records[index]
                         when :streams_aggregated; records
                         end
              failed_records.push(
                original:      original,
                error_code:    record[:error_code],
                error_message: record[:error_message]
              )
            end
            failed_records
          end

          def retry_records(failed_records)
            case request_type
            when :streams, :firehose
              failed_records.map{|r| r[:original] }
            when :streams_aggregated
              failed_records.first[:original]
            end
          end

          def failed_count(res)
            failed_field = case request_type
                           when :streams;            :failed_record_count
                           when :streams_aggregated; :failed_record_count
                           when :firehose;           :failed_put_count
                           end
            res[failed_field]
          end

          def results(res)
            result_field = case request_type
                           when :streams;            :records
                           when :streams_aggregated; :records
                           when :firehose;           :request_responses
                           end
            res[result_field]
          end

          def give_up_retries(failed_records)
            failed_records.each {|record|
              log.error(truncate 'Could not put record, Error: %s/%s, Record: %s' % [
                record[:error_code],
                record[:error_message],
                record[:original]
              ])
            }

            if @drop_failed_records_after_batch_request_retries
              # Increment num_errors to monitor batch request failure from "monitor_agent" or "fluent-plugin-prometheus"
              increment_num_errors
            else
              # Raise error and return chunk to Fluentd for retrying
              case request_type
              # @see https://docs.aws.amazon.com/kinesis/latest/APIReference/API_PutRecords.html
              # @see https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/Kinesis/Client.html#put_records-instance_method
              # @see https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/Kinesis/Errors.html
              when :streams, :streams_aggregated
                provisioned_throughput_exceeded_records = failed_records.select { |record| record[:error_code] == 'ProvisionedThroughputExceededException' }
                target_failed_record = provisioned_throughput_exceeded_records.first || failed_records.first
                target_error = provisioned_throughput_exceeded_records.empty? ?
                  Aws::Kinesis::Errors::ServiceError :
                  Aws::Kinesis::Errors::ProvisionedThroughputExceededException
              # @see https://docs.aws.amazon.com/kinesis/latest/APIReference/API_PutRecords.html
              # @see https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/Firehose/Client.html#put_record_batch-instance_method
              # @see https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/Firehose/Errors.html
              when :firehose
                service_unavailable_exception_records = failed_records.select { |record| record[:error_code] == 'ServiceUnavailableException' }
                target_failed_record = service_unavailable_exception_records.first || failed_records.first
                target_error = service_unavailable_exception_records.empty? ?
                  Aws::Firehose::Errors::ServiceError :
                  Aws::Firehose::Errors::ServiceUnavailableException
              end
              log.error("Raise #{target_failed_record[:error_code]} and return chunk to Fluentd buffer for retrying")
              raise target_error.new(Seahorse::Client::RequestContext.new, target_failed_record[:error_message])
            end
          end

          def increment_num_errors
            # Prepare Fluent::Plugin::Output instance variables to count errors in this method.
            # These instance variables are initialized here for possible future breaking changes of Fluentd.
            @num_errors ||= 0
            # @see https://github.com/fluent/fluentd/commit/d245454658d16170431d276fcd5849fb0d88ab2b
            if Gem::Version.new(Fluent::VERSION) >= Gem::Version.new('1.7.0')
              @counter_mutex ||= Mutex.new
              @counter_mutex.synchronize{ @num_errors += 1 }
            else
              @counters_monitor ||= Monitor.new
              @counters_monitor.synchronize{ @num_errors += 1 }
            end
          end

          class Backoff
            def initialize
              @count = 0
            end

            def next
              value = calc(@count)
              @count += 1
              value
            end

            def reset
              @count = 0
            end

            private

            def calc(count)
              (2 ** count) * scaling_factor
            end

            def scaling_factor
              0.3 + (0.5-rand) * 0.1
            end
          end
        end
      end
    end
  end
end
