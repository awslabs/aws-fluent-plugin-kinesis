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

require 'fluent_plugin_kinesis/version'

module Fluent
  module KinesisHelper
    module API
      def configure(conf)
        super
        if @batch_request_max_count > self.class::BatchRequestLimitCount
          raise ConfigError, "batch_request_max_count can't be grater than #{self.class::BatchRequestLimitCount}."
        end
        if @batch_request_max_size > self.class::BatchRequestLimitSize
          raise ConfigError, "batch_request_max_size can't be grater than #{self.class::BatchRequestLimitSize}."
        end
        @region = client.config.region if @region.nil?
      end

      def start
        detach_multi_process do
          super
        end
      end

      private

      def client_options
        options = {
          user_agent_suffix: "fluent-plugin-kinesis/#{request_type}/#{FluentPluginKinesis::VERSION}",
          credentials: credentials,
        }
        options.update(region:          @region)          unless @region.nil?
        options.update(http_proxy:      @http_proxy)      unless @http_proxy.nil?
        options.update(endpoint:        @endpoint)        unless @endpoint.nil?
        options.update(ssl_verify_peer: @ssl_verify_peer) unless @ssl_verify_peer.nil?
        if @debug
          options.update(logger: Logger.new(log.out))
          options.update(log_level: :debug)
        end
        options
      end

      def split_to_batches(records)
        batch_by_limit(records, @batch_request_max_count, @batch_request_max_size)
      end

      def batch_by_limit(records, max_count, max_size)
        result, buf, size = records.inject([[],[],0]){|(result, buf, size), record|
          record_size = size_of_values(record)
          if buf.size+1 > max_count or size+record_size > max_size
            result << buf
            buf = []
            size = 0
          end
          buf << record
          size += record_size
          [result, buf, size]
        }
        result << buf
      end

      def size_of_values(record)
        record.values_at(:data, :partition_key).compact.map(&:size).inject(:+) || 0
      end

      def batch_request_with_retry(batch, retry_count=0, backoff: nil)
        backoff ||= Backoff.new
        res = batch_request(batch)
        if failed_count(res) > 0
          failed_records = collect_failed_records(batch, res)
          if retry_count < @retries_on_batch_request
            backoff.reset if @reset_backoff_if_success and any_records_shipped?(res)
            sleep(backoff.next)
            log.warn(truncate 'Retrying to request batch. Retry count: %d, Retry records: %d' % [retry_count, failed_records.size])
            retry_batch = failed_records.map{|r| r[:original] }
            batch_request_with_retry(retry_batch, retry_count + 1, backoff: backoff)
          else
            give_up_retries(failed_records)
          end
        end
      end

      def any_records_shipped?(res)
        results(res).size > failed_count(res)
      end

      def collect_failed_records(records, res)
        failed_records = []
        results(res).each_with_index do |record, index|
          next unless record[:error_code]
          failed_records.push(
            original:      records[index],
            error_code:    record[:error_code],
            error_message: record[:error_message]
          )
        end
        failed_records
      end

      def failed_count(res)
        failed_field = case request_type
                       when :streams;  :failed_record_count
                       when :firehose; :failed_put_count
                       end
        res[failed_field]
      end

      def results(res)
        result_field = case request_type
                       when :streams;  :records
                       when :firehose; :request_responses
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
