# Fluent plugin for Amazon Kinesis

[![Build Status](https://travis-ci.com/awslabs/aws-fluent-plugin-kinesis.svg?branch=master)](https://travis-ci.com/awslabs/aws-fluent-plugin-kinesis)
[![Gem Version](https://badge.fury.io/rb/fluent-plugin-kinesis.svg)](https://rubygems.org/gems/fluent-plugin-kinesis)
[![Gem Downloads](https://img.shields.io/gem/dt/fluent-plugin-kinesis.svg)](https://rubygems.org/gems/fluent-plugin-kinesis)

[Fluentd][fluentd] output plugin
that sends events to [Amazon Kinesis Data Streams][streams] and [Amazon Kinesis Data Firehose][firehose]. Also it supports [KPL Aggregated Record Format][kpl]. This gem includes three output plugins respectively:

- `kinesis_streams`
- `kinesis_firehose`
- `kinesis_streams_aggregated`

Also, there is a [documentation on Fluentd official site][fluentd-doc-kinesis].

**Note**: This README is for v3. Plugin v3 is almost compatible with v2. If you use v1, see the [old README][v1-readme].

## Installation
This Fluentd plugin is available as the `fluent-plugin-kinesis` gem from RubyGems.

    gem install fluent-plugin-kinesis

Or you can install this plugin for [td-agent][td-agent] as:

    td-agent-gem install fluent-plugin-kinesis

If you would like to build by yourself and install, see the section below. Your need [bundler][bundler] for this.

In case of using with Fluentd: Fluentd will be also installed via the process below.

    git clone https://github.com/awslabs/aws-fluent-plugin-kinesis.git
    cd aws-fluent-plugin-kinesis
    bundle install
    bundle exec rake build
    bundle exec rake install

Also, you can use this plugin with td-agent: You have to install td-agent before installing this plugin.

    git clone https://github.com/awslabs/aws-fluent-plugin-kinesis.git
    cd aws-fluent-plugin-kinesis
    bundle install
    bundle exec rake build
    fluent-gem install pkg/fluent-plugin-kinesis

Or just download specify your Ruby library path. Below is the sample for specifying your library path via RUBYLIB.

    git clone https://github.com/awslabs/aws-fluent-plugin-kinesis.git
    cd aws-fluent-plugin-kinesis
    bundle install
    export RUBYLIB=$RUBYLIB:/path/to/aws-fluent-plugin-kinesis/lib

## Dependencies
 * Ruby 2.3.0+
 * Fluentd 0.14.22+ (td-agent v3.1.0+)

## Basic Usage
Here are general procedures for using this plugin:

 1. Install.
 1. Edit configuration
 1. Run Fluentd or td-agent

You can run this plugin with Fluentd as follows:

 1. Install.
 1. Edit configuration file and save it as 'fluentd.conf'.
 1. Then, run `fluentd -c /path/to/fluentd.conf`

To run with td-agent, it would be as follows:

 1. Install.
 1. Edit configuration file provided by td-agent.
 1. Then, run or restart td-agent.

## Getting started
Assume you use Amazon EC2 instances with Instance profile. If you want to use specific credentials, see [Credentials](#configuration-credentials).

### kinesis_streams
    <match your_tag>
      @type kinesis_streams
      region us-east-1
      stream_name your_stream
      partition_key key  # Otherwise, use random partition key
    </match>
For more details, see [Configuration: kinesis_streams](#configuration-kinesis_streams).

### kinesis_firehose
    <match your_tag>
      @type kinesis_firehose
      region us-east-1
      delivery_stream_name your_stream
    </match>
For more details, see [Configuration: kinesis_firehose](#configuration-kinesis_firehose).

### kinesis_streams_aggregated
    <match your_tag>
      @type kinesis_streams_aggregated
      region us-east-1
      stream_name your_stream
      # Unlike kinesis_streams, there is no way to use dynamic partition key.
      # fixed_partition_key or random.
    </match>
For more details, see [Configuration: kinesis_streams_aggregated](#configuration-kinesis_streams_aggregated).

### For better throughput
Add configurations like below:

      flush_interval 1
      chunk_limit_size 1m
      flush_thread_interval 0.1
      flush_thread_burst_interval 0.01
      flush_thread_count 15

When you use Fluent v1.0 (td-agent3), write these configurations in buffer section. For more details, see [Config: Buffer Section][fluentd-buffer-section].

Note: Each value should be adjusted to your system by yourself.

## Configuration: Credentials
To put records into Amazon Kinesis Data Streams or Firehose, you need to provide AWS security credentials somehow. Without specifying credentials in config file, this plugin automatically fetch credential just following AWS SDK for Ruby does (environment variable, shared profile, and instance profile).

This plugin uses the same configuration in [fluent-plugin-s3][fluent-plugin-s3], but also supports aws session tokens for temporary credentials. 

**aws_key_id**

AWS access key id. This parameter is required when your agent is not running on EC2 instance with an IAM Role. When using an IAM role, make sure to configure `instance_profile_credentials`. Usage can be found below.

**aws_sec_key**

AWS secret key. This parameter is required when your agent is not running on EC2 instance with an IAM Role.

**aws_ses_token**

AWS session token. This parameter is optional, but can be provided if using MFA or temporary credentials when your agent is not running on EC2 instance with an IAM Role. 

**aws_iam_retries**

The number of attempts to make (with exponential backoff) when loading instance profile credentials from the EC2 metadata service using an IAM role. Defaults to 5 retries.

### assume_role_credentials
Typically, you can use AssumeRole for cross-account access or federation.

    <match *>
      @type kinesis_streams

      <assume_role_credentials>
        role_arn          ROLE_ARN
        role_session_name ROLE_SESSION_NAME
      </assume_role_credentials>
    </match>

See also:

*   [Using IAM Roles - AWS Identity and Access
    Management](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use.html)
*   [Aws::STS::Client](https://docs.aws.amazon.com/sdkforruby/api/Aws/STS/Client.html)
*   [Aws::AssumeRoleCredentials](https://docs.aws.amazon.com/sdkforruby/api/Aws/AssumeRoleCredentials.html)

**role_arn (required)**

The Amazon Resource Name (ARN) of the role to assume.

**role_session_name (required)**

An identifier for the assumed role session.

**policy**

An IAM policy in JSON format.

**duration_seconds**

The duration, in seconds, of the role session. The value can range from 900 seconds (15 minutes) to 3600 seconds (1 hour). By default, the value is set to 3600 seconds.

**external_id**

A unique identifier that is used by third parties when assuming roles in their customers' accounts.

**sts_http_proxy**

Proxy url for proxying requests to amazon sts service api. This needs to be  set up independently from global http_proxy parameter for the use case in which requests to kinesis api are going via kinesis vpc endpoint but requests to sts api have to go via http proxy.
It should be added to assume_role_credentials configuration stanza in the next format:
    sts_http_proxy http://[username:password]@hostname:port

**sts_endpoint_url**

STS API endpoint url. This can be used to override the default global STS API endpoint of sts.amazonaws.com. Using regional endpoints may be preferred to reduce latency, and are required if utilizing a PrivateLink VPC Endpoint for STS API calls.


### web_identity_credentials

Similar to the assume_role_credentials, but for usage in EKS.

    <match *>
      @type kinesis_streams

      <web_identity_credentials>
        role_arn          ROLE_ARN
        role_session_name ROLE_SESSION_NAME
        web_identity_token_file AWS_WEB_IDENTITY_TOKEN_FILE
      </web_identity_credentials>
    </match>

See also:

*   [Using IAM Roles - AWS Identity and Access Management](http://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use.html)
*   [IAM Roles For Service Accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts-technical-overview.html)
*   [Aws::STS::Client](http://docs.aws.amazon.com/sdkforruby/api/Aws/STS/Client.html)
*   [Aws::AssumeRoleWebIdentityCredentials](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/AssumeRoleWebIdentityCredentials.html)

**role_arn (required)**

The Amazon Resource Name (ARN) of the role to assume.

**role_session_name (required)**

An identifier for the assumed role session.

**web_identity_token_file (required)**

The absolute path to the file on disk containing the OIDC token

**policy**

An IAM policy in JSON format.

**duration_seconds**

The duration, in seconds, of the role session. The value can range from
900 seconds (15 minutes) to 43200 seconds (12 hours). By default, the value
is set to 3600 seconds (1 hour).

### instance_profile_credentials

Retrieve temporary security credentials via HTTP request. This is useful on EC2 instance.

    <match *>
      @type kinesis_streams

      <instance_profile_credentials>
        ip_address IP_ADDRESS
        port       PORT
      </instance_profile_credentials>
    </match>

See also:

*   [Aws::InstanceProfileCredentials](https://docs.aws.amazon.com/sdkforruby/api/Aws/InstanceProfileCredentials.html)
*   [Temporary Security Credentials - AWS Identity and Access
    Management](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp.html)
*   [Instance Metadata and User Data - Amazon Elastic Compute
    Cloud](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html)

**retries**

Number of times to retry when retrieving credentials. Default is 5.

**ip_address**

Default is 169.254.169.254.

**port**

Default is 80.

**http_open_timeout**

Default is 5.

**http_read_timeout**

Default is 5.

### shared_credentials

This loads AWS access credentials from local ini file. This is useful for local developing.

    <match *>
      @type kinesis_streams

      <shared_credentials>
        path         PATH
        profile_name PROFILE_NAME
      </shared_credentials>
    </match>

See also:

*   [Aws::SharedCredentials](https://docs.aws.amazon.com/sdkforruby/api/Aws/SharedCredentials.html)

**path**

Path to the shared file. Defaults to "#{Dir.home}/.aws/credentials".

**profile_name**

Defaults to 'default' or `[ENV]('AWS_PROFILE')`.

### process_credentials

This loads AWS access credentials from an external process.

    <match *>
      @type kinesis_streams

      <process_credentials>
        process CMD
      </process_credentials>
    </match>

See also:

*   [Aws::ProcessCredentials](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/ProcessCredentials.html)
*   [Sourcing Credentials From External Processes](https://docs.aws.amazon.com/cli/latest/topic/config-vars.html#sourcing-credentials-from-external-processes)

**process (required)**

Command to be executed as an external process.

## Configuration: Format

### format (section)
This plugin uses `Fluent::TextFormatter` to serialize record to string. See [formatter.rb] for more details. By default, it uses `json` formatter same as specific like below:

    <match *>
      @type kinesis_streams

      <format>
        @type json
      </format>
    </match>

For other configurations of `json` formatter, see [json formatter plugin][fluentd-formatter-json].

### inject (section)
This plugin uses `Fluent::TimeFormatter` and other injection configurations. See [inject.rb] for more details.

For example, the config below will add `time` field whose value is event time with nanosecond and `tag` field whose value is its tag.

    <match *>
      @type kinesis_streams

      <inject>
        time_key time
        tag_key tag
      </inject>
    </match>

By default, `time_type string` and `time_format %Y-%m-%dT%H:%M:%S.%N%z` are already set to be applicable to Elasticsearch sub-second format. Although, you can use any configuration.

Also, there are some format related options below:

### data_key
If your record contains a field whose string should be sent to Amazon Kinesis directly (without formatter), use this parameter to specify the field. In that case, other fields than **data_key** are thrown away and never sent to Amazon Kinesis. Default `nil`, which means whole record will be formatted and sent.

### compression
Specifing compression way for data of each record. Current accepted options are `zlib`. Otherwise, no compression will be preformed.

### log_truncate_max_size
Integer, default 1024. When emitting the log entry, the message will be truncated by this size to avoid infinite loop when the log is also sent to Kinesis. The value 0 means no truncation.

### chomp_record
Boolean. Default `false`. If it is enabled, the plugin calls chomp and removes separator from the end of each record. This option is for compatible format with plugin v2. See [#142](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/142) for more details.  
When you use [kinesis_firehose](#kinesis_firehose) output, [append_new_line](#append_new_line) option is `true` as default. If [append_new_line](#append_new_line) is enabled, the plugin calls chomp as [chomp_record](#chomp_record) is `true` before appending `\n` to each record. Therefore, you don't need to enable [chomp_record](#chomp_record) option when you use [kinesis_firehose](#kinesis_firehose) with default configuration. If you want to set [append_new_line](#append_new_line) `false`, you can choose [chomp_record](#chomp_record) `false` (default) or `true` (compatible format with plugin v2).

## Configuration: API
### region
AWS region of your stream. It should be in form like `us-east-1`, `us-west-2`. Refer to [Regions and Endpoints in AWS General Reference][region] for supported regions.

Default `nil`, which means try to find from environment variable `AWS_REGION`.

### max_record_size
The upper limit of size of each record. Default is 1 MB which is the limitation of Kinesis.

### http_proxy
HTTP proxy for API calling. Default `nil`.

### endpoint
API endpoint URL, for testing. Default `nil`.

### ssl_verify_peer
Boolean. Disable if you want to verify ssl connection, for testing. Default `true`.

### debug
Boolean. Enable if you need to debug Amazon Kinesis Data Firehose API call. Default is `false`.

## Configuration: Batch request
### retries_on_batch_request
Integer, default is 8. The plugin will put multiple records to Amazon Kinesis Data Streams in batches using PutRecords. A set of records in a batch may fail for reasons documented in the Kinesis Service API Reference for PutRecords. Failed records will be retried **retries_on_batch_request** times. If a record fails all retries an error log will be emitted.

### reset_backoff_if_success
Boolean, default `true`. If enabled, when after retrying, the next retrying checks the number of succeeded records on the former batch request and reset exponential backoff if there is any success. Because batch request could be composed by requests across shards, simple exponential backoff for the batch request wouldn't work some cases.

### batch_request_max_count
Integer, default 500. The number of max count of making batch request from record chunk. It can't exceed the default value because it's API limit.

Default:

- `kinesis_streams`: 500
- `kinesis_firehose`: 500
- `kinesis_streams_aggregated`: 100,000

### batch_request_max_size
Integer. The number of max size of making batch request from record chunk. It can't exceed the default value because it's API limit.

Default:

- `kinesis_streams`: 5 MB
- `kinesis_firehose`: 4 MB
- `kinesis_streams_aggregated`: 1 MB

### drop_failed_records_after_batch_request_retries
Boolean, default `true`.

If *drop_failed_records_after_batch_request_retries* is enabled (default), the plugin will drop failed records when batch request fails after retrying max times configured as *retries_on_batch_request*. This dropping can be monitored from [monitor_agent](https://docs.fluentd.org/input/monitor_agent) or [fluent-plugin-prometheus](https://docs.fluentd.org/monitoring-fluentd/monitoring-prometheus) as *retry_count* or *num_errors* metrics.

If *drop_failed_records_after_batch_request_retries* is disabled, the plugin will raise error and return chunk to Fluentd buffer when batch request fails after retrying max times. Fluentd will retry to send chunk records according to retry config in [Buffer Section](https://docs.fluentd.org/configuration/buffer-section). Note that this retryng may create duplicate records since [PutRecords API](https://docs.aws.amazon.com/kinesis/latest/APIReference/API_PutRecords.html) of Kinesis Data Streams and [PutRecordBatch API](https://docs.aws.amazon.com/firehose/latest/APIReference/API_PutRecordBatch.html) of Kinesis Data Firehose may return a partially successful response.

### monitor_num_of_batch_request_retries
Boolean, default `false`. If enabled, the plugin will increment *retry_count* monitoring metrics after internal retrying to send batch request. This configuration enables you to monitor [ProvisionedThroughputExceededException](https://docs.aws.amazon.com/kinesis/latest/APIReference/API_PutRecords.html) from [monitor_agent](https://docs.fluentd.org/input/monitor_agent) or [fluent-plugin-prometheus](https://docs.fluentd.org/monitoring-fluentd/monitoring-prometheus). Note that *retry_count* metrics will be counted by the plugin in addition to original Fluentd buffering mechanism if *monitor_num_of_batch_request_retries* is enabled.

## Configuration: kinesis_streams
Here are `kinesis_streams` specific configurations.

### stream_name
Name of the stream to put data.

As of Fluentd v1, built-in placeholders are supported. Now, you can also use built-in placeholders for this parameter.

**NOTE:**
Built-in placeholders require target key information in your buffer section attributes.

e.g.)

When you specify the following `stream_name` configuration with built-in placeholder:

```aconf
stream_name "${$.kubernetes.annotations.kinesis_streams}"
```

you ought to specify the corresponding attributes in buffer section:

```aconf
# $.kubernetes.annotations.kinesis_streams needs to be set in buffer attributes
<buffer $.kubernetes.annotations.kinesis_streams>
   # ...
</buffer>
```

For more details, refer [Placeholders section in the official Fluentd document](https://docs.fluentd.org/configuration/buffer-section#placeholders).

### partition_key
A key to extract partition key from JSON object. Default `nil`, which means partition key will be generated randomly.

## Configuration: kinesis_firehose
Here are `kinesis_firehose` specific configurations.

### delivery_stream_name
Name of the delivery stream to put data.

As of Fluentd v1, built-in placeholders are supported. Now, you can also use built-in placeholders for this parameter.

**NOTE:**
Built-in placeholders require target key information in your buffer section attributes.

e.g.)

When you specify the following `delivery_stream_name` configuration with built-in placeholder:

```aconf
delivery_stream_name "${$.kubernetes.annotations.kinesis_firehose_streams}"
```

you ought to specify the corresponding attributes in buffer section:

```aconf
# $.kubernetes.annotations.kinesis_firehose_streams needs to be set in buffer attributes
<buffer $.kubernetes.annotations.kinesis_firehose_streams>
   # ...
</buffer>
```

For more details, refer [Placeholders section in the official Fluentd document](https://docs.fluentd.org/configuration/buffer-section#placeholders).

### append_new_line
Boolean. Default `true`. If it is enabled, the plugin adds new line character (`\n`) to each serialized record.  
Before appending `\n`, plugin calls chomp and removes separator from the end of each record as [chomp_record](#chomp_record) is `true`. Therefore, you don't need to enable [chomp_record](#chomp_record) option when you use [kinesis_firehose](#kinesis_firehose) output with default configuration ([append_new_line](#append_new_line) is `true`). If you want to set [append_new_line](#append_new_line) `false`, you can choose [chomp_record](#chomp_record) `false` (default) or `true` (compatible format with plugin v2).

## Configuration: kinesis_streams_aggregated
Here are `kinesis_streams_aggregated` specific configurations.

### stream_name
Name of the stream to put data.

As of Fluentd v1, built-in placeholders are supported. Now, you can also use built-in placeholders for this parameter.

**NOTE:**
Built-in placeholders require target key information in your buffer section attributes.

e.g.)

When you specify the following `stream_name` configuration with built-in placeholder:

```aconf
stream_name "${$.kubernetes.annotations.kinesis_streams_aggregated}"
```

you ought to specify the corresponding attributes in buffer section:

```aconf
# $.kubernetes.annotations.kinesis_streams_aggregated needs to be set in buffer attributes
<buffer $.kubernetes.annotations.kinesis_streams_aggregated>
   # ...
</buffer>
```

For more details, refer [Placeholders section in the official Fluentd document](https://docs.fluentd.org/configuration/buffer-section#placeholders).

### fixed_partition_key
A value of fixed partition key. Default `nil`, which means partition key will be generated randomly.

Note: if you specified this option, all records go to a single shard.

## Development

To launch `fluentd` process with this plugin for development, follow the steps below:

    git clone https://github.com/awslabs/aws-fluent-plugin-kinesis.git
    cd aws-fluent-plugin-kinesis
    make # will install gems dependency
    bundle exec fluentd -c /path/to/fluent.conf

To launch using specified version of Fluentd, use `BUNDLE_GEMFILE` environment variable:

    BUNDLE_GEMFILE=$PWD/gemfiles/Gemfile.td-agent-3.3.0 bundle exec fluentd -c /path/to/fluent.conf

## Contributing

Bug reports and pull requests are welcome on [GitHub][github].

## Related Resources

* [Amazon Kinesis Data Streams Developer Guide](http://docs.aws.amazon.com/kinesis/latest/dev/introduction.html)
* [Amazon Kinesis Data Firehose Developer Guide](http://docs.aws.amazon.com/firehose/latest/dev/what-is-this-service.html)

[fluentd]: https://www.fluentd.org/
[streams]: https://aws.amazon.com/kinesis/streams/
[firehose]: https://aws.amazon.com/kinesis/firehose/
[kpl]: https://github.com/awslabs/amazon-kinesis-producer/blob/master/aggregation-format.md
[td-agent]: https://github.com/treasure-data/omnibus-td-agent
[bundler]: https://bundler.io/
[region]: https://docs.aws.amazon.com/general/latest/gr/rande.html#ak_region
[fluentd-buffer-section]: https://docs.fluentd.org/configuration/buffer-section
[fluentd-formatter-json]: https://docs.fluentd.org/formatter/json
[github]: https://github.com/awslabs/aws-fluent-plugin-kinesis
[formatter.rb]: https://github.com/fluent/fluentd/blob/master/lib/fluent/formatter.rb
[inject.rb]: https://github.com/fluent/fluentd/blob/master/lib/fluent/plugin_helper/inject.rb
[fluentd-doc-kinesis]: https://docs.fluentd.org/how-to-guides/kinesis-stream
[fluent-plugin-s3]: https://github.com/fluent/fluent-plugin-s3
[v1-readme]: https://github.com/awslabs/aws-fluent-plugin-kinesis/blob/v1/README.md
