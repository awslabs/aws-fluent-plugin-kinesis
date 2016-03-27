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

require 'tempfile'
require 'concurrent'

module KinesisProducer
  class Daemon
    FixnumMax = (2 ** (64 - 2)) - 1

    def initialize(binary, handler, options)
      @binary  = binary
      @handler = handler

      @configuration             = options[:configuration] || {}
      @credentials               = options[:credentials]
      @metrics_credentials       = options[:metrics_credentials]
      @credentials_refresh_delay = options[:credentials_refresh_delay] || 5000
      @logger                    = options[:logger]
      @debug                     = options[:debug]

      @executor = Concurrent::CachedThreadPool.new
      @shutdown = Concurrent::AtomicBoolean.new(false)
      @outgoing_messages = Queue.new
      @incoming_messages = Queue.new

      if debug?
        @meters = {
          add_message:     Meter.new,
          send_message:    Meter.new,
          receive_message: Meter.new,
          return_message:  Meter.new,
        }
      end
    end

    def start
      @executor.post do
        create_pipes
        start_child
      end
    end

    def destroy
      @shutdown.make_true
      if @pid
        Process.kill("TERM", @pid)
        Process.waitpid(@pid)
        sleep 1 # TODO
      end
      delete_pipes
    end

    def add(message)
      @outgoing_messages.push(message)
      @meters[:add_message].mark if debug?
    end

    private

    def create_pipes
      @in_pipe  = temp_pathname('amz-aws-kpl-in-pipe-')
      @out_pipe = temp_pathname('amz-aws-kpl-out-pipe-')
      system("mkfifo", @in_pipe.to_path, @out_pipe.to_path)
      sleep 1 # TODO
    end

    def delete_pipes
      @in_channel.close  unless @in_channel.nil?
      @out_channel.close unless @out_channel.nil?
      @in_pipe.unlink
      @out_pipe.unlink
    rescue Errno::ENOENT
    end

    def temp_pathname(basename)
      tempfile = Tempfile.new(basename)
      ObjectSpace.undefine_finalizer(tempfile)
      file = tempfile.path
      File.delete(file)
      Pathname.new(file)
    end

    def start_child
      start_child_daemon
      connect_to_child
      start_loops
    end

    def start_child_daemon
      @pid = Process.fork do
        Process.setsid
        configuration = make_configuration_message
        credentials = make_set_credentials_message
        command = [@binary, @out_pipe.to_path, @in_pipe.to_path, to_hex(configuration), to_hex(credentials)]
        if @metrics_credentials
          metrics_credentials = make_set_metrics_credentials_message
          command.push(to_hex(metrics_credentials))
        end
        exec(*command)
      end
      sleep 1 # TODO
    end

    def connect_to_child
      @in_channel  = @in_pipe.open('r')
      @out_channel = @out_pipe.open('w')
    end

    def start_loops
      start_loop_for(:send_message)
      start_loop_for(:receive_message)
      start_loop_for(:return_message)
      start_loop_for(:update_credentials)
      start_loop_for(:tick) if debug?
    end

    def start_loop_for(method)
      @executor.post do
        while @shutdown.false?
          send(method)
          @meters[method].mark if debug? and @meters.include?(method)
        end
      end
    end

    def send_message
      message = @outgoing_messages.pop
      size = [message.size].pack('N*')
      @out_channel.write(size)
      @out_channel.write(message)
      @out_channel.flush
    end

    def receive_message
      size = @in_channel.read(4)
      data = @in_channel.read(size.unpack('N*').first)
      @incoming_messages.push(data)
    end

    def return_message
      data = @incoming_messages.pop
      message = KinesisProducer::Protobuf::Message.decode(data)
      @handler.on_message(message)
    end

    def update_credentials
      add(make_set_credentials_message)
      add(make_set_metrics_credentials_message) if @metrics_credentials
      sleep(@credentials_refresh_delay.to_f/1000)
    end

    def make_configuration_message
      configuration = @configuration
      KinesisProducer::ConfigurationFields.each do |field|
        if configuration[field.name].nil?
          configuration[field.name] = field.default_value
        end
      end
      config = KinesisProducer::Protobuf::Configuration.new(configuration)
      make_message(0, :configuration, config)
    end

    def make_set_credentials_message
      make_set_credential_message(@credentials)
    end

    def make_set_metrics_credentials_message
      make_set_credential_message(@metrics_credentials, true)
    end

    def make_set_credential_message(credentials, for_metrics = false)
      return nil if credentials.nil?
      cred = KinesisProducer::Protobuf::Credentials.new(
        akid:       credentials.credentials.access_key_id,
        secret_key: credentials.credentials.secret_access_key,
        token:      credentials.credentials.session_token
      )
      set_credentials = KinesisProducer::Protobuf::SetCredentials.new(credentials: cred, for_metrics: for_metrics)
      make_message(FixnumMax, :set_credentials, set_credentials)
    end

    def make_message(id, target, value)
      KinesisProducer::Protobuf::Message.new(id: id, target => value).encode
    end

    def to_hex(message)
      message.unpack('H*').first
    end

    def tick
      out = @meters.each_value.map do |meter|
        sprintf("%5d", meter.tick)
      end
      @logger.debug("[#{Thread.current.object_id}] "+out.join(" ")) if debug?
      sleep 1
    end

    def debug?
      @debug
    end

    class Meter
      def initialize
        @count = Concurrent::AtomicFixnum.new(0)
        @previous_tick_time = Time.now.to_f
        @current_rate = 0.0
        tick
      end

      def mark(count = 1)
        @count.increment(count)
      end

      def tick
        @current_rate = @count.value.to_f / (Time.now.to_f - @previous_tick_time)
        @count.value = 0
        @previous_tick_time = Time.now.to_f
        current_rate
      end

      def current_rate
        @current_rate
      end
    end
  end
end
