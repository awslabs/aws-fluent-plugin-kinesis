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
require 'aws-sdk-core'
require 'aws-sdk-firehose'

class KinesisHelperClientTest < Test::Unit::TestCase
  class Mock
    include Fluent::KinesisHelper::Client

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
    @object = Mock.new
    Aws.shared_config.fresh
  end

  def teardown
    WebMock.disable!
    FakeFS.deactivate!
    FakeFS::FileSystem.clear
  end

  def test_instance_profile
    setup_instance_profile
    credentials = @object.client.config.credentials
    assert_equal 'akid',          credentials.credentials.access_key_id
    assert_equal 'secret',        credentials.credentials.secret_access_key
    assert_equal 'session-token', credentials.credentials.session_token
  end

  def test_instance_profile_refresh
    setup_instance_profile(Time.now.utc + 299)
    credentials = @object.client.config.credentials
    assert_equal 'akid-2',          credentials.credentials.access_key_id
    assert_equal 'secret-2',        credentials.credentials.secret_access_key
    assert_equal 'session-token-2', credentials.credentials.session_token
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
    path = '/latest/meta-data/iam/security-credentials/'
    stub_request(:get, "http://169.254.169.254#{path}").
      to_return(:status => 200, :body => "profile-name\n")
    stub_request(:get, "http://169.254.169.254#{path}profile-name").
      to_return(:status => 200, :body => resp).
      to_return(:status => 200, :body => resp2)
  end
end
