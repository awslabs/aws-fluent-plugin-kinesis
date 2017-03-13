# Fluent plugin for Amazon Kinesis

[![Build Status](https://travis-ci.org/awslabs/aws-fluent-plugin-kinesis.svg?branch=master)](https://travis-ci.org/awslabs/aws-fluent-plugin-kinesis)

[Fluentd][fluentd] output plugin
that sends events to [Amazon Kinesis Streams][streams] and [Amazon Kinesis Firehose][firehose]. Also it supports [KPL Aggregated record format][kpl]. This gem includes three output plugins respectively:

- `kinesis_streams`
- `kinesis_firehose`
- `kinesis_streams_aggregated`

Also, there is a [documentation on Fluentd official site][fluentd-doc-kinesis].

## Installation
This fluentd plugin is available as the `fluent-plugin-kinesis` gem from RubyGems.

    gem install fluent-plugin-kinesis

Or you can install this plugin for [td-agent][td-agent] as:

    td-agent-gem install fluent-plugin-kinesis

If you would like to build by yourself and install, please see the section below. Your need [bundler][bundler] for this.

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
 * Ruby 2.1.0+
 * Fluentd 0.14.12+

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
For more detail, see [Configuration: kinesis_streams](#configuration-kinesis_streams)

### kinesis_firehose
    <match your_tag>
      @type kinesis_firehose
      region us-east-1
      delivery_stream_name your_stream
    </match>
For more detail, see [Configuration: kinesis_firehose](#configuration-kinesis_firehose)

### kinesis_streams_aggregated
    <match your_tag>
      @type kinesis_streams_aggregated
      region us-east-1
      stream_name your_stream
      # Unlike kinesis_streams, there is no way to use dynamic partition key.
      # fixed_partition_key or random.
    </match>
For more detail, see [Configuration: kinesis_streams_aggregated](#configuration-kinesis_streams_aggregated)

### For better throughput
Add configuration like below:

      flush_interval 1
      buffer_chunk_limit 1m
      try_flush_interval 0.1
      queued_chunk_flush_interval 0.01
      num_threads 15

Note: Each value should be adjusted to your system by yourself.

## Configuration: Credentials
To put records into Amazon Kinesis Streams or Firehose, you need to provide AWS security credentials somehow. Without specifiying credentials in config file, this plugin automatically fetch credential just following AWS SDK for Ruby does (environment variable, shared profile, and instance profile).

This plugin uses the same configuration in [fluent-plugin-s3][fluent-plugin-s3].

**aws_key_id**

AWS access key id. This parameter is required when your agent is not
running on EC2 instance with an IAM Role. When using an IAM role, make 
sure to configure `instance_profile_credentials`. Usage can be found below.

**aws_sec_key**

AWS secret key. This parameter is required when your agent is not running
on EC2 instance with an IAM Role.

**aws_iam_retries**

The number of attempts to make (with exponential backoff) when loading
instance profile credentials from the EC2 metadata service using an IAM
role. Defaults to 5 retries.

### assume_role_credentials

Typically, you use AssumeRole for cross-account access or federation.

    <match *>
      @type kinesis_streams

      <assume_role_credentials>
        role_arn          ROLE_ARN
        role_session_name ROLE_SESSION_NAME
      </assume_role_credentials>
    </match>

See also:

*   [Using IAM Roles - AWS Identity and Access
    Management](http://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use.html)
*   [Aws::STS::Client](http://docs.aws.amazon.com/sdkforruby/api/Aws/STS/Client.html)
*   [Aws::AssumeRoleCredentials](http://docs.aws.amazon.com/sdkforruby/api/Aws/AssumeRoleCredentials.html)

**role_arn (required)**

The Amazon Resource Name (ARN) of the role to assume.

**role_session_name (required)**

An identifier for the assumed role session.

**policy**

An IAM policy in JSON format.

**duration_seconds**

The duration, in seconds, of the role session. The value can range from
900 seconds (15 minutes) to 3600 seconds (1 hour). By default, the value
is set to 3600 seconds.

**external_id**

A unique identifier that is used by third parties when assuming roles in
their customers' accounts.

### instance_profile_credentials

Retrieve temporary security credentials via HTTP request. This is useful on
EC2 instance.

    <match *>
      @type kinesis_streams

      <instance_profile_credentials>
        ip_address IP_ADDRESS
        port       PORT
      </instance_profile_credentials>
    </match>

See also:

*   [Aws::InstanceProfileCredentials](http://docs.aws.amazon.com/sdkforruby/api/Aws/InstanceProfileCredentials.html)
*   [Temporary Security Credentials - AWS Identity and Access
    Management](http://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp.html)
*   [Instance Metadata and User Data - Amazon Elastic Compute
    Cloud](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html)

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

This loads AWS access credentials from local ini file. This is useful for
local developing.

    <match *>
      @type kinesis_streams

      <shared_credentials>
        path         PATH
        profile_name PROFILE_NAME
      </shared_credentials>
    </match>

See also:

*   [Aws::SharedCredentials](http://docs.aws.amazon.com/sdkforruby/api/Aws/SharedCredentials.html)

**path**

Path to the shared file. Defaults to "#{Dir.home}/.aws/credentials".

**profile_name**

Defaults to 'default' or `[ENV]('AWS_PROFILE')`.

## Configuraion: Format
This plugin use `Fluent::TextFormatter` to serialize record to string. For more detail, see [formatter.rb].

    <match *>
      @type kinesis_streams

      <format>
        @type json
      </format>
    </match>

Also, there are some format related options below:

### include_time_key
Defalut `false`. If you want to include `time` field in your record, set `true`.

### include_tag_key
Defalut `false`. If you want to include `tag` field in your record, set `true`.

### data_key
If your record contains a field whose string should be sent to Amazon Kinesis directly (without formatter), use this parameter to specify the field. In that case, other fileds than **data_key** are thrown away and never sent to Amazon Kinesis. Default `nil`, which means whole record will be formatted and sent.

### log_truncate_max_size
Integer, default 0. When emitting the log entry, the message will be truncated by this size to avoid infinite loop when the log is also sent to Kinesis. The value 0 (default) means no truncation.

## Configuraion: API
### region
AWS region of your stream. It should be in form like `us-east-1`, `us-west-2`. Refer to [Regions and Endpoints in AWS General Reference][region] for supported regions.

Default `nil`, which means try to find from environment variable `AWS_REGION`.

### max_record_size
The upper limit of size of each record. Default is 1 MB which is the limitation of Kinesis.

### http_proxy
HTTP proxy for API calling. Default `nil`.

### endpoint
API endpoint URL, for testing. Defalut `nil`.

### ssl_verify_peer
Boolean. Disable if you want to verify ssl conncetion, for testing. Default `true`.

### debug
Boolean. Enable if you need to debug Amazon Kinesis Firehose API call. Default is `false`.

## Configuration: Batch request
### retries_on_batch_request
Integer, default is 3. The plugin will put multiple records to Amazon Kinesis Streams in batches using PutRecords. A set of records in a batch may fail for reasons documented in the Kinesis Service API Reference for PutRecords. Failed records will be retried **retries_on_batch_request** times. If a record fails all retries an error log will be emitted.

### reset_backoff_if_success
Boolean, default `true`. If enabled, when after retrying, the next retrying checks the number of succeeded records on the former batch request and reset exponential backoff if there is any success. Because batch request could be composed by requests across shards, simple exponential backoff for the batch request wouldn't work some cases.

### batch_request_max_count
Integer, default 500. The number of max count of making batch request from record chunk. It can't exceed the default value because it's API limit.

Default:

- `kinesis_streams`: 500
- `kinesis_firehose`: 500
- `kinesis_streams_aggregated`: 1,000,000

### batch_request_max_size
Integer. The number of max size of making batch request from record chunk. It can't exceed the default value because it's API limit.

Default:

- `kinesis_streams`: 5 MB
- `kinesis_firehose`: 4 MB
- `kinesis_streams_aggregated`: 1 MB

## Configuration: kinesis_streams
Here are `kinesis_streams` specific configurations.

### stream_name
Name of the stream to put data.

### partition_key
A key to extract partition key from JSON object. Default `nil`, which means partition key will be generated randomly.

## Configuration: kinesis_firehose
Here are `kinesis_firehose` specific configurations.

### delivery_stream_name
Name of the delivery stream to put data.

### append_new_line
Boolean. Default `true`. If it is enabled, the plugin add new line character (`\n`) to each serialized record.

## Configuration: kinesis_streams_aggregated
Here are `kinesis_streams_aggregated` specific configurations.

### stream_name
Name of the stream to put data.

### fixed_partition_key
A value of fixed partition key. Default `nil`, which means partition key will be generated randomly.

Note: if you specified this option, all records go to a single shard.

## Development

To launch `fluentd` process with this plugin for development, follow the steps below:

    git clone https://github.com/awslabs/aws-fluent-plugin-kinesis.git
    cd aws-fluent-plugin-kinesis
    make # will install gems and download KPL jar file and extract binaries
    bundle exec fluentd -c /path/to/fluent.conf

If you want to run benchmark, use `make benchmark`.

## Contributing

Bug reports and pull requests are welcome on [GitHub][github].

## Related Resources

* [Amazon Kinesis Streams Developer Guide](http://docs.aws.amazon.com/kinesis/latest/dev/introduction.html)
* [Amazon Kinesis Firehose Developer Guide](http://docs.aws.amazon.com/firehose/latest/dev/what-is-this-service.html)

[fluentd]: http://fluentd.org/
[streams]: https://aws.amazon.com/kinesis/streams/
[firehose]: https://aws.amazon.com/kinesis/firehose/
[kpl]: https://github.com/awslabs/amazon-kinesis-producer/blob/master/aggregation-format.md
[td-agent]: https://github.com/treasure-data/td-agent
[bundler]: http://bundler.io/
[region]: http://docs.aws.amazon.com/general/latest/gr/rande.html#ak_region
[fluentd_buffer]: http://docs.fluentd.org/articles/buffer-plugin-overview
[github]: https://github.com/awslabs/aws-fluent-plugin-kinesis
[formatter.rb]: https://github.com/fluent/fluentd/blob/master/lib/fluent/formatter.rb
[fluentd-doc-kinesis]: http://docs.fluentd.org/articles/kinesis-stream
[fluent-plugin-s3]: https://github.com/fluent/fluent-plugin-s3