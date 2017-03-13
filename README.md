# Fluent plugin for Amazon Kinesis

[![Build Status](https://travis-ci.org/awslabs/aws-fluent-plugin-kinesis.svg?branch=master)](https://travis-ci.org/awslabs/aws-fluent-plugin-kinesis)

[Fluentd][fluentd] output plugin
that sends events to [Amazon Kinesis Streams][streams] (via both API and [Kinesis Producer Library (KPL)][producer]) and [Amazon Kinesis Firehose][firehose] (via API). This gem includes three output plugins respectively:

- `kinesis_streams`
- `kinesis_producer`
- `kinesis_firehose`

Also, there is a [documentation on Fluentd official site][fluentd-doc-kinesis].

## Warning: `kinesis` is no longer supported
As of v1.0.0, `kinesis` plugin is no longer supported. Still you can use the plugin, but if you see the warn log below, please consider to use `kinesis_streams`.

    [warn]: Deprecated warning: out_kinesis is no longer supported after v1.0.0. Please check out_kinesis_streams out.

If you still want to use `kinesis`, please see [the old README][old-readme].

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
 * Ruby 2.0.0+
 * Fluentd 0.10.58+

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

### kinesis_producer
    <match your_tag>
      @type kinesis_producer
      region us-east-1
      stream_name your_stream
      partition_key key  # Otherwise, use random partition key
    </match>
For more detail, see [Configuration: kinesis_producer](#configuration-kinesis_producer)

### kinesis_firehose
    <match your_tag>
      @type kinesis_firehose
      region us-east-1
      delivery_stream_name your_stream
    </match>
For more detail, see [Configuration: kinesis_firehose](#configuration-kinesis_firehose)

### For better throughput
Add configuration like below:

      flush_interval 1
      buffer_chunk_limit 1m
      try_flush_interval 0.1
      queued_chunk_flush_interval 0.01
      num_threads 15

Note: Each value should be adjusted to your system by yourself.

## Configuration: Credentials
To put records into Amazon Kinesis Streams or Firehose, you need to provide AWS security credentials.

The credential provider will be choosen by the steps below:

- Use [**shared_credentials**](#shared_credentials) section if you set it
- Use [**assume_role_credentials**](#assume_role_credentials) section if you set it
- Otherwise, default provider chain:
    - [**aws_key_id**](#aws_key_id) and [**aws_sec_key**](#aws_sec_key)
    - Environment variables (ex. `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, etc.)
    - Default shared credentials (`default` in `~/.aws/credentials`)
    - Instance profile (For Amazon EC2)

### aws_key_id
AWS access key id.

### aws_sec_key
AWS secret access key.

### shared_credentials
Use this config section to specify shared credential file path and profile name. If you want to use default profile (`default` in `~/.aws/credentials`), you don't have to specify here. For example, you can specify the config like below:

      <shared_credentials>
        profile_name "your_profile_name"
      </shared_credentials>

#### profile_name
Profile name of the credential file.

#### path
Path for the credential file.

### assume_role_credentials
Use this config section for cross account access. For example, you can specify the config like below:

      <assume_role_credentials>
        role_arn "your_role_arn_in_cross_account_to_assume"
      </assume_role_credentials>

#### role_arn
IAM Role to be assumed with [AssumeRole][assume_role].

#### external_id
A unique identifier that is used by third parties when [assuming roles][assmue_role] in their customers' accounts. Use this option with `role_arn` for third party cross account access. For detail, please see [How to Use an External ID When Granting Access to Your AWS Resources to a Third Party][external_id].

## Configuraion: Format
This plugin use `Fluent::TextFormatter` to serialize record to string. For more detail, see [formatter.rb]. Also, this plugin includes `Fluent::SetTimeKeyMixin` and `Fluent::SetTagKeyMixin` to use **include_time_key** and **include_tagkey**.

### formatter
Default `json`.

### include_time_key
Defalut `false`. If you want to include `time` field in your record, set `true`.

### include_tag_key
Defalut `false`. If you want to include `tag` field in your record, set `true`.

### data_key
If your record contains a field whose string should be sent to Amazon Kinesis directly (without formatter), use this parameter to specify the field. In that case, other fileds than **data_key** are thrown away and never sent to Amazon Kinesis. Default `nil`, which means whole record will be formatted and sent.

### log_truncate_max_size
Integer, default 0. When emitting the log entry, the message will be truncated by this size to avoid infinite loop when the log is also sent to Kinesis. The value 0 (default) means no truncation.

## Configuration: kinesis_streams
Here are `kinesis_streams` specific configurations.

### stream_name
Name of the stream to put data.

### region
AWS region of your stream. It should be in form like `us-east-1`, `us-west-2`. Refer to [Regions and Endpoints in AWS General Reference][region] for supported regions.

Default `nil`, which means try to find from environment variable `AWS_REGION`.

### partition_key
A key to extract partition key from JSON object. Default `nil`, which means partition key will be generated randomly.

### retries_on_batch_request
Integer, default is 3. The plugin will put multiple records to Amazon Kinesis Streams in batches using PutRecords. A set of records in a batch may fail for reasons documented in the Kinesis Service API Reference for PutRecords. Failed records will be retried **retries_on_batch_request** times. If a record fails all retries an error log will be emitted.

### reset_backoff_if_success
Boolean, default `true`. If enabled, when after retrying, the next retrying checks the number of succeeded records on the former batch request and reset exponential backoff if there is any success. Because batch request could be composed by requests across shards, simple exponential backoff for the batch request wouldn't work some cases.

### batch_request_max_count
Integer, default 500. The number of max count of making batch request from record chunk. It can't exceed the default value because it's API limit.

### batch_request_max_size
Integer, default 5 * 1024 * 1024. The number of max size of making batch request from record chunk. It can't exceed the default value because it's API limit.

### http_proxy
HTTP proxy for API calling. Default `nil`.

### endpoint
API endpoint URL, for testing. Defalut `nil`.

### ssl_verify_peer
Boolean. Disable if you want to verify ssl conncetion, for testing. Default `true`.

### debug
Boolean. Enable if you need to debug Amazon Kinesis Firehose API call. Default is `false`.

## Configuration: kinesis_producer
Here are `kinesis_producer` specific configurations.

### stream_name
Name of the stream to put data.

### region
AWS region of your stream. It should be in form like `us-east-1`, `us-west-2`. Refer to [Regions and Endpoints in AWS General Reference][region] for supported regions.

Default `nil`, which means try to find from environment variable `AWS_REGION`. If both **region** and `AWS_REGION` are not defined, KPL will try to find region from Amazon EC2 metadata.

### partition_key
A key to extract partition key from JSON object. Default `nil`, which means partition key will be generated randomly.

### debug
Boolean. Enable if you need to debug Kinesis Producer Library metrics. Default is `false`.

### kinesis_producer
This section is configuration for Kinesis Producer Library. Almost all of description comes from [deault_config.propertites of KPL Java Sample Application][default_config.properties]. You should specify configurations below inside `<kinesis_producer>` section like:

    <match your_tag>
      @type kinesis_producer
      region us-east-1
      stream_name your_stream
      <kinesis_producer>
        record_max_buffered_time 10
      </kinesis_producer>
    </match>

#### aggregation_enabled
Enable aggregation. With aggregation, multiple user records are packed into a single KinesisRecord. If disabled, each user record is sent in its own KinesisRecord.

If your records are small, enabling aggregation will allow you to put many more records than you would otherwise be able to for a shard before getting throttled.

Default: `true`

#### aggregation_max_count
Maximum number of items to pack into an aggregated record.

There should be normally no need to adjust this. If you want to limit the time records spend buffering, look into record_max_buffered_time instead.

Default: 4294967295
Minimum: 1
Maximum (inclusive): 9223372036854775807

#### aggregation_max_size
Maximum number of bytes to pack into an aggregated Kinesis record.

There should be normally no need to adjust this. If you want to limit the time records spend buffering, look into [**record_max_buffered_time**](#record_max_buffered_time) instead.

If a record has more data by itself than this limit, it will bypass the aggregator. Note the backend enforces a limit of 50KB on record size. If you set this beyond 50KB, oversize records will be rejected at the backend.

Default: 51200
Minimum: 64
Maximum (inclusive): 1048576

#### collection_max_count
Maximum number of items to pack into an PutRecords request.

There should be normally no need to adjust this. If you want to limit the time records spend buffering, look into [**record_max_buffered_time**](#record_max_buffered_time) instead.

Default: 500
Minimum: 1
Maximum (inclusive): 500

#### collection_max_size
Maximum amount of data to send with a PutRecords request.

There should be normally no need to adjust this. If you want to limit the time records spend buffering, look into [**record_max_buffered_time**](#record_max_buffered_time) instead.

Records larger than the limit will still be sent, but will not be grouped with others.

Default: 5242880
Minimum: 52224
Maximum (inclusive): 9223372036854775807

#### connect_timeout
Timeout (milliseconds) for establishing TLS connections.

Default: 6000
Minimum: 100
Maximum (inclusive): 300000

#### custom_endpoint
Use a custom Kinesis and CloudWatch endpoint.

Mostly for testing use. Note this does not accept protocols or paths, only host names or ip addresses. There is no way to disable TLS. The KPL always connects with TLS.

Expected pattern: `^([A-Za-z0-9-\\.]+)?$`

#### fail_if_throttled
If `true`, throttled puts are not retried. The records that got throttled will be failed immediately upon receiving the throttling error. This is useful if you want to react immediately to any throttling without waiting for the KPL to retry. For example, you can use a different hash key to send the throttled record to a backup shard.

If `false`, the KPL will automatically retry throttled puts. The KPL performs backoff for shards that it has received throttling errors from, and will avoid flooding them with retries. Note that records may fail from expiration (see [**record_ttl**](#record_ttl)) if they get delayed for too long because of
throttling.

Default: `false`

#### log_level
Minimum level of logs. Messages below the specified level will not be logged. Logs for the native KPL daemon show up on stderr.

Default: `info`
Expected pattern: `info|warning|error`

#### max_connections
Maximum number of connections to open to the backend. HTTP requests are sent in parallel over multiple connections.

Setting this too high may impact latency and consume additional resources without increasing throughput.

Default: 4
Minimum: 1
Maximum (inclusive): 128

#### metrics_granularity
Controls the granularity of metrics that are uploaded to CloudWatch. Greater granularity produces more metrics.

When `shard` is selected, metrics are emitted with the stream name and shard id as dimensions. On top of this, the same metric is also emitted with only the stream name dimension, and lastly, without the stream name. This means for a particular metric, 2 streams with 2 shards (each) will produce 7 CloudWatch metrics, one for each shard, one for each stream, and one overall, all describing the same statistics, but at different levels of granularity.

When `stream` is selected, per shard metrics are not uploaded; when `global` is selected, only the total aggregate for all streams and all shards are uploaded.

Consider reducing the granularity if you're not interested in shard-level metrics, or if you have a large number of shards.

If you only have 1 stream, select `global`; the global data will be equivalent to that for the stream.

Refer to the metrics documentation for details about each metric.

Default: `shard`
Expected pattern: `global|stream|shard`

#### metrics_level
Controls the number of metrics that are uploaded to CloudWatch.

`none` disables all metrics.

`summary` enables the following metrics: UserRecordsPut, KinesisRecordsPut, ErrorsByCode, AllErrors, BufferingTime.

`detailed` enables all remaining metrics.

Refer to the metrics documentation for details about each metric.

Default: `detailed`
Expected pattern: `none|summary|detailed`

#### metrics_namespace
The namespace to upload metrics under.

If you have multiple applications running the KPL under the same AWS account, you should use a different namespace for each application.

If you are also using the KCL, you may wish to use the application name you have configured for the KCL as the the namespace here. This way both your KPL and KCL metrics show up under the same namespace.

Default: `KinesisProducerLibrary`
Expected pattern: `(?!AWS/).{1,255}`

#### metrics_upload_delay
Delay (in milliseconds) between each metrics upload.

For testing only. There is no benefit in setting this lower or higher in production.

Default: 60000
Minimum: 1
Maximum (inclusive): 60000

#### min_connections
Minimum number of connections to keep open to the backend.

There should be no need to increase this in general.

Default: 1
Minimum: 1
Maximum (inclusive): 16

#### port
Server port to connect to. Only useful with [**custom_endpoint**](#custom_endpoint).

Default: 443
Minimum: 1
Maximum (inclusive): 65535

#### rate_limit
Limits the maximum allowed put rate for a shard, as a percentage of the backend limits.

The rate limit prevents the producer from sending data too fast to a shard. Such a limit is useful for reducing bandwidth and CPU cycle wastage from sending requests that we know are going to fail from throttling.

Kinesis enforces limits on both the number of records and number of bytes per second. This setting applies to both.

The default value of 150% is chosen to allow a single producer instance to completely saturate the allowance for a shard. This is an aggressive setting. If you prefer to reduce throttling errors rather than completely saturate the shard, consider reducing this setting.

Default: 150
Minimum: 1
Maximum (inclusive): 9223372036854775807

#### record_max_buffered_time
Maximum amount of itme (milliseconds) a record may spend being buffered before it gets sent. Records may be sent sooner than this depending on the other buffering limits.

This setting provides coarse ordering among records - any two records will be reordered by no more than twice this amount (assuming no failures and retries and equal network latency).

The library makes a best effort to enforce this time, but cannot guarantee that it will be precisely met. In general, if the CPU is not overloaded, the library will meet this deadline to within 10ms.

Failures and retries can additionally increase the amount of time records spend in the KPL. If your application cannot tolerate late records, use the [**record_ttl**](#record_ttl) setting to drop records that do not get transmitted in time.

Setting this too low can negatively impact throughput.

Default: 100
Maximum (inclusive): 9223372036854775807

#### record_ttl
Set a time-to-live on records (milliseconds). Records that do not get successfully put within the limit are failed.

This setting is useful if your application cannot or does not wish to tolerate late records. Records will still incur network latency after they leave the KPL, so take that into consideration when choosing a value for this setting.

If you do not wish to lose records and prefer to retry indefinitely, set record_ttl to a large value like INT_MAX. This has the potential to cause head-of-line blocking if network issues or throttling occur. You can respond to such situations by using the metrics reporting functions of the KPL. You may also set [**fail_if_throttled**](#fail_if_throttled) to true to prevent automatic retries in case of throttling.

Default: 30000
Minimum: 100
Maximum (inclusive): 9223372036854775807

#### request_timeout
The maximum total time (milliseconds) elapsed between when we begin a HTTP request and receiving all of the response. If it goes over, the request will be timed-out.

Note that a timed-out request may actually succeed at the backend. Retrying then leads to duplicates. Setting the timeout too low will therefore increase the probability of duplicates.

Default: 6000
Minimum: 100
Maximum (inclusive): 600000

#### verify_certificate
Verify the endpoint's certificate. Do not disable unless using [**custom_endpoint**](#custom_endpoint) for testing. Never disable this in production.

Default: `true`

#### credentials_refresh_delay
Interval milliseconds for refreshing credentials seding to KPL.

Defalut 5000

## Configuration: kinesis_firehose
Here are `kinesis_firehose` specific configurations.

### delivery_stream_name
Name of the delivery stream to put data.

### region
AWS region of your stream. It should be in form like `us-east-1`, `us-west-2`. Refer to [Regions and Endpoints in AWS General Reference][region] for supported regions.

Default `nil`, which means try to find from environment variable `AWS_REGION`.

### append_new_line
Boolean. Default `true`. If it is enabled, the plugin add new line character (`\n`) to each serialized record.  

### retries_on_batch_request
Integer, default is 3. The plugin will put multiple records to Amazon Kinesis Firehose in batches using PutRecordBatch. A set of records in a batch may fail for reasons documented in the Kinesis Service API Reference for PutRecordBatch. Failed records will be retried **retries_on_batch_request** times. If a record fails all retries an error log will be emitted.

### reset_backoff_if_success
Boolean, default `true`. If enabled, when after retrying, the next retrying checks the number of succeeded records on the former batch request and reset exponential backoff if there is any success. Because batch request could be composed by requests across shards, simple exponential backoff for the batch request wouldn't work some cases.

### batch_request_max_count
Integer, default 500. The number of max count of making batch request from record chunk. It can't exceed the default value because it's API limit.

### batch_request_max_size
Integer, default 4 * 1024*1024. The number of max size of making batch request from record chunk. It can't exceed the default value because it's API limit.

### http_proxy
HTTP proxy for API calling. Default `nil`.

### endpoint
API endpoint URL, for testing. Defalut `nil`.

### ssl_verify_peer
Boolean. Disable if you want to verify ssl conncetion, for testing. Default `true`.

### debug
Boolean. Enable if you need to debug Amazon Kinesis Firehose API call. Default is `false`.

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
[producer]: http://docs.aws.amazon.com/kinesis/latest/dev/developing-producers-with-kpl.html
[td-agent]: https://github.com/treasure-data/td-agent
[bundler]: http://bundler.io/
[assume_role]: http://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRole.html
[external_id]: http://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-user_externalid.html
[region]: http://docs.aws.amazon.com/general/latest/gr/rande.html#ak_region
[fluentd_buffer]: http://docs.fluentd.org/articles/buffer-plugin-overview
[github]: https://github.com/awslabs/aws-fluent-plugin-kinesis
[formatter.rb]: https://github.com/fluent/fluentd/blob/master/lib/fluent/formatter.rb
[default_config.properties]: https://github.com/awslabs/amazon-kinesis-producer/blob/v0.10.2/java/amazon-kinesis-producer-sample/default_config.properties
[old-readme]: https://github.com/awslabs/aws-fluent-plugin-kinesis/blob/master/README-v0.4.md
[fluentd-doc-kinesis]: http://docs.fluentd.org/articles/kinesis-stream
