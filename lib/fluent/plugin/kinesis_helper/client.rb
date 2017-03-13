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

require 'fluent/configurable'

module Fluent
  module KinesisHelper
    module Client
      module ClientParams
        include Fluent::Configurable
        config_param :region, :string,  default: nil

        config_param :http_proxy,      :string, default: nil, secret: true
        config_param :endpoint,        :string, default: nil
        config_param :ssl_verify_peer, :bool,   default: true

        config_param :aws_key_id,  :string, default: nil, secret: true
        config_param :aws_sec_key, :string, default: nil, secret: true
        config_section :assume_role_credentials, multi: false do
          desc "The Amazon Resource Name (ARN) of the role to assume"
          config_param :role_arn, :string, secret: true
          desc "An identifier for the assumed role session"
          config_param :role_session_name, :string
          desc "An IAM policy in JSON format"
          config_param :policy, :string, default: nil
          desc "The duration, in seconds, of the role session (900-3600)"
          config_param :duration_seconds, :integer, default: nil
          desc "A unique identifier that is used by third parties when assuming roles in their customers' accounts."
          config_param :external_id, :string, default: nil, secret: true
        end
        config_section :instance_profile_credentials, multi: false do
          desc "Number of times to retry when retrieving credentials"
          config_param :retries, :integer, default: nil
          desc "IP address (default:169.254.169.254)"
          config_param :ip_address, :string, default: nil
          desc "Port number (default:80)"
          config_param :port, :integer, default: nil
          desc "Number of seconds to wait for the connection to open"
          config_param :http_open_timeout, :float, default: nil
          desc "Number of seconds to wait for one block to be read"
          config_param :http_read_timeout, :float, default: nil
          # config_param :delay, :integer or :proc, :default => nil
          # config_param :http_degub_output, :io, :default => nil
        end
        config_section :shared_credentials, multi: false do
          desc "Path to the shared file. (default: $HOME/.aws/credentials)"
          config_param :path, :string, default: nil
          desc "Profile name. Default to 'default' or ENV['AWS_PROFILE']"
          config_param :profile_name, :string, default: nil
        end
      end

      def self.included(mod)
        mod.include ClientParams
      end

      def configure(conf)
        super
        @region = client.config.region if @region.nil?
      end

      def client
        @client ||= client_class.new(client_options)
      end

      private

      def client_class
        case request_type
        when :streams, :streams_aggregated
          require 'aws-sdk-kinesis'
          Aws::Kinesis::Client
        when :firehose
          require 'aws-sdk-firehose'
          Aws::Firehose::Client
        end
      end

      def client_options
        options = setup_credentials
        options.update(
          user_agent_suffix: "fluent-plugin-kinesis/#{request_type}/#{FluentPluginKinesis::VERSION}"
        )
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

      def setup_credentials
        options = {}
        credentials_options = {}
        case
        when @aws_key_id && @aws_sec_key
          options[:access_key_id] = @aws_key_id
          options[:secret_access_key] = @aws_sec_key
        when @assume_role_credentials
          c = @assume_role_credentials
          credentials_options[:role_arn] = c.role_arn
          credentials_options[:role_session_name] = c.role_session_name
          credentials_options[:policy] = c.policy if c.policy
          credentials_options[:duration_seconds] = c.duration_seconds if c.duration_seconds
          credentials_options[:external_id] = c.external_id if c.external_id
          if @region
            credentials_options[:client] = Aws::STS::Client.new(region: @region)
          end
          options[:credentials] = Aws::AssumeRoleCredentials.new(credentials_options)
        when @instance_profile_credentials
          c = @instance_profile_credentials
          credentials_options[:retries] = c.retries if c.retries
          credentials_options[:ip_address] = c.ip_address if c.ip_address
          credentials_options[:port] = c.port if c.port
          credentials_options[:http_open_timeout] = c.http_open_timeout if c.http_open_timeout
          credentials_options[:http_read_timeout] = c.http_read_timeout if c.http_read_timeout
          if ENV["AWS_CONTAINER_CREDENTIALS_RELATIVE_URI"]
            options[:credentials] = Aws::ECSCredentials.new(credentials_options)
          else
            options[:credentials] = Aws::InstanceProfileCredentials.new(credentials_options)
          end
        when @shared_credentials
          c = @shared_credentials
          credentials_options[:path] = c.path if c.path
          credentials_options[:profile_name] = c.profile_name if c.profile_name
          options[:credentials] = Aws::SharedCredentials.new(credentials_options)
        else
          # Use default credentials
          # See http://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Client.html
        end
        options
      end
    end
  end
end
