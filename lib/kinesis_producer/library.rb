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

require 'concurrent'
require 'os'

module KinesisProducer
  class Library
    class Handler
      def initialize(futures)
        @futures = futures
      end

      def on_message(message)
        if !message.put_record_result.nil?
          on_put_record_result(message)
        elsif !message.metrics_response.nil?
          on_metrics_response(message)
        end
      end

      def on_put_record_result(message)
        source_id = message.source_id
        result = message.put_record_result
        f = @futures.fetch(source_id)
        @futures.delete(source_id)
        if result.success
          f.set(result)
        else
          f.fail(StandardError.new(result.to_hash))
        end
      end

      def on_metrics_response(message)
        source_id = message.source_id
        response = message.metrics_response
        f = @futures.fetch(source_id)
        @futures.delete(source_id)
        f.set(response.metrics)
      end
    end

    class << self
      def binary
        case
        when OS.linux?;   Binary::Files['linux']
        when OS.osx?;     Binary::Files['osx']
        when OS.windows?; Binary::Files['windows']
        else; raise
        end
      end

      def default_binary_path
        root_dir = File.expand_path('../../..', __FILE__)
        File.join(root_dir, binary)
      end
    end

    def initialize(options)
      @binary_path = options.delete(:binary_path) || self.class.default_binary_path
      @message_id = Concurrent::AtomicFixnum.new(1)
      @futures = Concurrent::Map.new
      @child = Daemon.new(@binary_path, Handler.new(@futures), options)
      @child.start
    end

    def destroy
      flush_sync
      @child.destroy
    end

    def put_record(options)
      f = Concurrent::IVar.new
      id = add_message(:put_record, KinesisProducer::Protobuf::PutRecord.new(options))
      @futures[id] = f
      f
    end

    def get_metrics(options = {})
      f = Concurrent::IVar.new
      id = add_message(:metrics_request, KinesisProducer::Protobuf::MetricsRequest.new(options))
      @futures[id] = f
      f.wait
      f.value
    end

    def flush(options = {})
      add_message(:flush, KinesisProducer::Protobuf::Flush.new(options))
    end

    def flush_sync
      while @futures.size > 0
        flush()
        sleep 0.5
      end
    end

    private

    def add_message(target, value)
      id = get_and_inc_message_id
      message = KinesisProducer::Protobuf::Message.new(id: id, target => value)
      @child.add(message.encode)
      id
    end

    def get_and_inc_message_id
      @message_id.increment
    end
  end
end
