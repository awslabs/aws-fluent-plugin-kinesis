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
    module Credentials
      def credentials
        @provider ||= case
          when @assume_role_credentials
            Aws::AssumeRoleCredentials.new(
              client:            Aws::STS::Client.new(region: @region),
              role_arn:          @assume_role_credentials.role_arn,
              external_id:       @assume_role_credentials.external_id,
              role_session_name: 'aws-fluent-plugin-kinesis',
              duration_seconds:  60 * 60,
          )
          when @shared_credentials
            Aws::SharedCredentials.new(
              profile_name: @shared_credentials.profile_name,
              path:         @shared_credentials.path,
            )
          else
            default_credentials_provider
          end
      end

      private

      def default_credentials_provider
        config_class = Struct.new(:access_key_id, :secret_access_key, :region, :session_token, :profile, :instance_profile_credentials_retries, :instance_profile_credentials_timeout)
        config = config_class.new(@aws_key_id, @aws_sec_key, @region)
        provider = Aws::CredentialProviderChain.new(config).resolve
        if provider.nil?
          raise Fluent::ConfigError, "You must specify credentials on ~/.aws/credentials, environment variables or instance profile for default credentials"
        end
        provider
      end
    end
  end
end
