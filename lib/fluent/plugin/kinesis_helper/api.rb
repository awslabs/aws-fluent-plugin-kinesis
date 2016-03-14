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

module Fluent
  module KinesisHelper
    module API
      def configure(conf)
        super
        @sleep_duration = exponential_backoff(retries_on_batch_request)
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

      def exponential_backoff(count)
        Array.new(count) {|n| ((2 ** n) * scaling_factor) }
      end

      def scaling_factor
        0.5 + rand * 0.1
      end

      def batch_by_limit(records, max_num, max_size)
        result, buf, size = records.inject([[],[],0]){|(result, buf, size), record|
          if buf.size >= max_num or size >= max_size
            result << buf
            buf = []
            size = 0
          end
          buf << record
          size += size_of_values(record)
          [result, buf, size]
        }
        result << buf
      end

      def size_of_values(record)
        record.values_at(:data, :partition_key).compact.map(&:size).inject(:+) || 0
      end

      def put_records_with_retry(batch, retry_count=0)
        res = put_records(batch)
        if failed_exists?(res)
          failed_records = collect_failed_records(batch, res)
          if retry_count < retries_on_batch_request
            sleep @sleep_duration[retry_count]
            log.warn('Retrying to request batch. Retry count: %d, Retry records: %d' % [retry_count, failed_records.size])
            put_records_with_retry(failed_records.map{|r| r[:original] }, retry_count + 1)
          else
            failed_records.each {|record|
              log.error('Could not put record, Error: %s/%s, Record: %s' % [
                record[:error_code],
                record[:error_message],
                record[:original]
              ])
            }
          end
        end
      end
      alias_method :put_record_batch_with_retry, :put_records_with_retry

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

      def failed_exists?(res)
        failed_field = case request_type
                       when :streams;  :failed_record_count
                       when :firehose; :failed_put_count
                       end
        res[failed_field] && res[failed_field] > 0
      end

      def results(res)
        result_field = case request_type
                       when :streams;  :records
                       when :firehose; :request_responses
                       end
        res[result_field]
      end

      def retries_on_batch_request
        case request_type
        when :streams;  @retries_on_putrecords
        when :firehose; @retries_on_putrecordbatch
        end
      end
    end
  end
end
