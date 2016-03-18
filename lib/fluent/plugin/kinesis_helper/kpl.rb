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
    module KPL
      def configure(conf)
        # To workaround when the kinesis_producer section is not specified
        if conf.elements.none?{|e|e.name == "kinesis_producer"}
          conf.add_element("kinesis_producer")
        end
        super(conf)
        if @region.nil?
          keys = %w(AWS_REGION AMAZON_REGION AWS_DEFAULT_REGION)
          @region = ENV.values_at(*keys).compact.first
        end
      end

      def start
        detach_multi_process do
          super
          client
        end
      end

      def shutdown
        super
        client.destroy
      end

      private

      def client_options
        {
          credentials: credentials,
          configuration: build_kpl_configuration,
          credentials_refresh_delay: @kinesis_producer.credentials_refresh_delay,
          debug: @debug,
          logger: log,
        }
      end

      def build_kpl_configuration
        configuration = @kinesis_producer.to_h
        configuration.update(region: @region) unless @region.nil?
      end

      def write_chunk_to_kpl(records)
        records.map do |record|
          client.put_record(record)
        end
      end

      def wait_futures(futures)
        futures.each do |f|
          f.wait
          result = f.value!
        end
      end

      def on_detach_process(i)
        Process.setsid
      end

      def on_exit_process(i)
        shutdown
      end
    end
  end
end
