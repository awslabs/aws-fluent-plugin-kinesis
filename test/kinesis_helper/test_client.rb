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

require_relative '../helper'
require 'fluent/plugin/kinesis_helper/client'
require 'tempfile'

class KinesisHelperClientTest < Test::Unit::TestCase
  class ProcessCredentials
    def self.process
      expiration = Time.now.utc + 3600
      response = {
          :SecretAccessKey => "secret",
          :SessionToken => "session-token",
          :Version => 1,
          :Expiration => expiration.strftime('%Y-%m-%dT%H:%M:%SZ'),
          :AccessKeyId => "akid"
      }.to_json

      "echo '#{response}'"
    end
  end

  class MockClientInstanceProfile
    include Fluent::Plugin::KinesisHelper::Client

    def initialize
      @region = 'us-east-1'
    end

    def request_type
      :firehose
    end
  end

  class MockClientProcessCredentials
    include Fluent::Plugin::KinesisHelper::Client

    def initialize
      @region = 'us-east-1'
      @process_credentials = ProcessCredentials
    end

    def request_type
      :firehose
    end
  end

  class MockWebIndentityCredentials
    include Fluent::Plugin::KinesisHelper::Client
    include Fluent::Configurable

    def initialize
      @region = 'us-east-1'
    end

    def request_type
      :firehose
    end
  end

  def self.startup
    Aws::Firehose::Client.new(region: 'us-east-1')
  end

  def setup
    WebMock.enable!
    FakeFS.activate!
  end

  def teardown
    WebMock.disable!
    FakeFS.deactivate!
    FakeFS::FileSystem.clear
  end

  def test_instance_profile
    Aws.shared_config.fresh
    setup_instance_profile
    credentials = MockClientInstanceProfile.new.client.config.credentials
    assert_equal 'akid',          credentials.credentials.access_key_id
    assert_equal 'secret',        credentials.credentials.secret_access_key
    assert_equal 'session-token', credentials.credentials.session_token
  end

  def test_instance_profile_refresh
    Aws.shared_config.fresh
    setup_instance_profile(Time.now.utc + 299)
    credentials = MockClientInstanceProfile.new.client.config.credentials
    assert_equal 'akid-2',          credentials.credentials.access_key_id
    assert_equal 'secret-2',        credentials.credentials.secret_access_key
    assert_equal 'session-token-2', credentials.credentials.session_token
  end

  def test_process_credentials
    omit_if(Gem::Version.new(Aws::CORE_GEM_VERSION) < Gem::Version.new('3.24.0'))
    credentials = MockClientProcessCredentials.new.client.config.credentials
    assert_equal 'akid',          credentials.credentials.access_key_id
    assert_equal 'secret',        credentials.credentials.secret_access_key
    assert_equal 'session-token', credentials.credentials.session_token
  end

  def test_process_credentials_config_error
    omit_if(Gem::Version.new(Aws::CORE_GEM_VERSION) >= Gem::Version.new('3.24.0'))
    assert_raise(Fluent::ConfigError) do
      MockClientProcessCredentials.new.client.config.credentials
    end
  end

  class WebIdentityCredentialsTest < self
    def setup
      sts = Aws::STS::Client.new(region: 'us-east-1', stub_responses: true)
      Aws::STS::Client.stubs(:new).with(anything).returns(sts)
    end

    def test_web_identity_credentials
      omit_if(Gem::Version.new(Aws::CORE_GEM_VERSION) < Gem::Version.new('3.65.0'))

      Tempfile.open("kinesis-") do |token_file|
        token_file.write("a token!")
        token_file.flush

        config = Fluent::Config::Element.new(
          'ROOT', '', {'region' => 'us-east-1'}, [
            Fluent::Config::Element.new('web_identity_credentials', '', {
                                          'role_arn' => 'arn',
                                          'web_identity_token_file' => token_file.path,
                                          'role_session_name' => 'session-name',
                                        }, [])
          ])
        credentials = MockWebIndentityCredentials.new
        credentials.configure(config)
        creds = credentials.client.config.credentials
        assert_true creds.is_a?(Aws::AssumeRoleWebIdentityCredentials)
        expected_creds = Aws::AssumeRoleCredentials.new(
          role_arn: 'arn',
          web_identity_token_file: token_file.path,
          role_session_name: 'session-name',
        )
        assert_equal expected_creds.client, creds.client
      end
    end
  end

  private

  def setup_instance_profile(expiration = Time.now.utc + 3600)
    expiration2 = expiration + 3600
    resp = <<-JSON.strip
{
  "Code" : "Success",
  "LastUpdated" : "2013-11-22T20:03:48Z",
  "Type" : "AWS-HMAC",
  "AccessKeyId" : "akid",
  "SecretAccessKey" : "secret",
  "Token" : "session-token",
  "Expiration" : "#{expiration.strftime('%Y-%m-%dT%H:%M:%SZ')}"
}
    JSON
    resp2 = <<-JSON.strip
{
  "Code" : "Success",
  "LastUpdated" : "2013-11-22T20:03:48Z",
  "Type" : "AWS-HMAC",
  "AccessKeyId" : "akid-2",
  "SecretAccessKey" : "secret-2",
  "Token" : "session-token-2",
  "Expiration" : "#{(expiration2).strftime('%Y-%m-%dT%H:%M:%SZ')}"
}
    JSON

    # Stub for IMDSv2 metadata token API
    if Gem::Version.new(Aws::CORE_GEM_VERSION) > Gem::Version.new('3.78.0')
      stub_request(:put, "http://169.254.169.254/latest/api/token").
        with(
          headers: {
            'X-Aws-Ec2-Metadata-Token-Ttl-Seconds'=>'21600'
          }).
        to_return(:status => 200, :body => "aws-ec2-metadata-token\n")
    end
    path = '/latest/meta-data/iam/security-credentials/'
    stub_request(:get, "http://169.254.169.254#{path}").
      to_return(:status => 200, :body => "profile-name\n")
    stub_request(:get, "http://169.254.169.254#{path}profile-name").
      to_return(:status => 200, :body => resp).
      to_return(:status => 200, :body => resp2)
  end
end
