# Fluent plugin for Amazon Kinesis

[![Build Status](https://travis-ci.org/awslabs/aws-fluent-plugin-kinesis.svg?branch=master)](https://travis-ci.org/awslabs/aws-fluent-plugin-kinesis)

The [Fluentd][fluentd] output plugin
sends events to [Amazon Kinesis Streams][streams] (via both API and [Amazon Kinesis Producer Library (KPL)][producer]) and [Amazon Kinesis Firehose][firehose] (via API). This gem includes three output plugins:

- `kinesis_streams`
- `kinesis_producer`
- `kinesis_firehose`

For more information, see the [documentation on the Fluentd official site][fluentd-doc-kinesis].

**Warning: `kinesis` is no longer supported**
As of v1.0.0, the `kinesis` plugin is no longer supported. You can still use the plugin; however, if you see the warn log below, consider using `kinesis_streams`.

    [warn]: Deprecated warning: out_kinesis is no longer supported after v1.0.0. Please check out_kinesis_streams out.

To use `kinesis`, see [the old README file][old-readme].

## Installation
This fluentd plugin is available as the `fluent-plugin-kinesis` gem from RubyGems:

    gem install fluent-plugin-kinesis

You can also install this plugin for [td-agent][td-agent] with the following command:

    td-agent-gem install fluent-plugin-kinesis

### Build and install manually
You need [bundler][bundler] to build and install manually.

If you are using Fluentd, it is also installed via this process:

    git clone https://github.com/awslabs/aws-fluent-plugin-kinesis.git
    cd aws-fluent-plugin-kinesis
    bundle install
    bundle exec rake build
    bundle exec rake install

You can also use this plugin with td-agent, but install td-agent before installing the plugin:

    git clone https://github.com/awslabs/aws-fluent-plugin-kinesis.git
    cd aws-fluent-plugin-kinesis
    bundle install
    bundle exec rake build
    fluent-gem install pkg/fluent-plugin-kinesis

You can also download this plugin by specifying your Ruby library path. The following code specifies a library path via RUBYLIB:

    git clone https://github.com/awslabs/aws-fluent-plugin-kinesis.git
    cd aws-fluent-plugin-kinesis
    bundle install
    export RUBYLIB=$RUBYLIB:/path/to/aws-fluent-plugin-kinesis/lib

## Dependencies
 * Ruby 2.0.0+
 * Fluentd 0.10.58+

## Basic Usage
Here are the general procedures for using this plugin:

 1. Install the plugin.
 1. Edit the configuration file.
 1. Run Fluentd or td-agent.

You can run this plugin with Fluentd. Edit the configuration file and save it as 'fluentd.conf'. Then, run the following command:
`fluentd -c /path/to/fluentd.conf`

To run with td-agent, edit the configuration file provided by td-agent. Then, run or restart td-agent.

## Configuration file
Use the following sections to guide your configuration settings.

### Getting started
Use Amazon EC2 instances with an IAM instance profile. To use specific credentials, see [Credentials](#configuration-credentials).

#### kinesis_streams
    <match your_tag>
      @type kinesis_streams
      region us-east-1
      stream_name your_stream
      partition_key key  # Otherwise, use random partition key
    </match>
For more information, see [Configuration: kinesis_streams](#configuration-kinesis_streams)

#### kinesis_producer
    <match your_tag>
      @type kinesis_producer
      region us-east-1
      stream_name your_stream
      partition_key key  # Otherwise, use random partition key
    </match>
For more information, see [Configuration: kinesis_producer](#configuration-kinesis_producer)

#### kinesis_firehose
    <match your_tag>
      @type kinesis_firehose
      region us-east-1
      delivery_stream_name your_stream
    </match>
For more information, see [Configuration: kinesis_firehose](#configuration-kinesis_firehose)

#### Improved throughput
For improved throughput, add a configuration block like the following:

      flush_interval 1
      buffer_chunk_limit 1m
      try_flush_interval 0.1
      queued_chunk_flush_interval 0.01
      num_threads 15

Note: Adjust each value to your system.

### Configuration: credentials
To put records into Streams or Firehose, you need to provide AWS security credentials. The credential provider is chosen by the configuration options that you set:

- Set the [**shared_credentials**](#shared_credentials) section
- Set the [**assume_role_credentials**](#assume_role_credentials) section
- Default provider chain:
    - [**aws_key_id**](#aws_key_id) and [**aws_sec_key**](#aws_sec_key)
    - Environment variables (example: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, etc.)
    - Default shared credentials (`default` in `~/.aws/credentials`)
    - Instance profile (for Amazon EC2)

#### aws_key_id
Your AWS access key ID.

#### aws_sec_key
Your AWS secret access key.

#### shared_credentials
The shared credential file path and profile name. To use the default profile (`default` in `~/.aws/credentials`), leave blank. Otherwise, you can configure this section using the following format:

      <shared_credentials>
        profile_name "your_profile_name"
      </shared_credentials>

##### profile_name
The profile name of the credential file.

##### path
The path for the credential file.

#### assume_role_credentials
Specifies cross-account access. To use the default profile (`default` in `~/.aws/credentials`), leave blank. Otherwise, you can configure this section using the following format:

      <assume_role_credentials>
        role_arn "your_role_arn_in_cross_account_to_assume"
      </assume_role_credentials>

##### role_arn
The IAM role to be assumed with [AssumeRole][assume_role].

##### external_id
A unique identifier that is used by third parties when [assuming roles][assmue_role] in their customers' accounts. Use this option with `role_arn` for third-party, cross-account access. For more information, see [How to Use an External ID When Granting Access to Your AWS Resources to a Third Party][external_id].

### Configuration: Format
This plugin uses `Fluent::TextFormatter` to serialize the record to the string. For more information, see [formatter.rb]. Also, this plugin includes `Fluent::SetTimeKeyMixin` and `Fluent::SetTagKeyMixin` to use **include_time_key** and **include_tagkey**.

#### formatter
The default is `json`.

#### include_time_key
The default is `false`. To include the `time` field in your record, set this parameter to `true`.

#### include_tag_key
The default is `false`. To include the `tag` field in your record, set this parameterto `true`.

#### data_key
If your record contains a field whose string should be sent to Amazon Kinesis directly (without the formatter), use this parameter to specify the field. In that case, fields other than **data_key** are thrown away and never sent to Amazon Kinesis. The default is `nil`, which means the whole record is formatted and sent.

#### log_truncate_max_size
Integer. The default is 0. When emitting the log entry, the message is truncated by this size to avoid an infinite loop when the log is also sent to Amazon Kinesis. The value 0 (default) means no truncation.

### Configuration: kinesis_streams
The following are `kinesis_streams`-specific configuration parameters.

#### stream_name
The name of the stream to put data.

#### region
The AWS Region of your stream. It should be in the form `us-east-1` or `us-west-2`. For more information, see [Regions and Endpoints][region]. The default is `nil`, which finds this value from the environment variable `AWS_REGION`.

#### partition_key
A key to extract the partition key from a JSON object. The default is `nil`, which means that the partition key is generated randomly.

#### retries_on_batch_request
Integer. The default is 3. The plugin puts multiple records to Amazon Kinesis Streams in batches, using PutRecords. A set of records in a batch may fail for reasons documented in the Amazon Kinesis Streams API Reference. Failed records are retried **retries_on_batch_request** times. If a record fails all retries, an error log is emitted.

#### reset_backoff_if_success
Boolean, default `true`. If enabled, when after retrying, the next retrying checks the number of succeeded records on the former batch request and reset exponential backoff if there is any success. Because batch request could be composed by requests across shards, simple exponential backoff for the batch request wouldn't work some cases.

#### batch_request_max_count
Integer. The default is 500. The max count for making batch requests from a record chunk. It can't exceed the default value because it is the API limit.

#### batch_request_max_size
Integer. The default is 5 * 1024 * 1024. The max size fpr making batch requests from a record chunk. It can't exceed the default value because it is the API limit.

#### http_proxy
The HTTP proxy for API calling. The default is `nil`.

#### endpoint
The API endpoint URL for testing. The default is `nil`.

#### ssl_verify_peer
Boolean. Disable to verify the SSL connection for testing. The default is `true`.

#### debug
Boolean. Enable to debug an Amazon Kinesis Firehose API call. The default is `false`.

### Configuration: kinesis_producer
The following are `kinesis_producer`-specific configuration parameters.

#### stream_name
The name of the stream to which to put data.

#### region
The AWS Region for your stream. It should be in the form `us-east-1` or `us-west-2`. For more information about supported regions, see [Regions and Endpoints][region]. The default is `nil`, which finds this value from the environment variable `AWS_REGION`. If both **region** and `AWS_REGION` are not defined, the KPL finds the region from Amazon EC2 metadata.

#### partition_key
A key to extract the partition key from the JSON object. The default is `nil`, which means the partition key is generated randomly.

#### debug
Boolean. Enable to debug KPL metrics. The default is `false`.

#### kinesis_producer
This section lists the configuration settings for the KPL. Almost all of the descriptions are based on the [default_config.properties file of the KPL Java Sample Application][default_config.properties]. Specify configuration parameters in this section as follows:

    <match your_tag>
      @type kinesis_producer
      region us-east-1
      stream_name your_stream
      <kinesis_producer>
        record_max_buffered_time 10
      </kinesis_producer>
    </match>

#### aggregation_enabled
Enable aggregation. With aggregation, multiple user records are packed into a single Amazon Kinesis record. If disabled, each user record is sent in its own record. If your records are small, enabling aggregation allows you to put many more records than you would otherwise be able to for a shard before getting throttled. The default is `true`.

#### aggregation_max_count
The maximum number of items to pack into an aggregated record. There should be normally be no need to adjust this. To limit the time records spend buffering, look into [**record_max_buffered_time**](#record_max_buffered_time) instead.

Default: 4294967295
Minimum: 1
Maximum (inclusive): 9223372036854775807

#### aggregation_max_size
The maximum number of bytes to pack into an aggregated Amazon Kinesis record. There should be normally be no need to adjust this. To limit the time records spend buffering, look into [**record_max_buffered_time**](#record_max_buffered_time) instead.

If a record has more data by itself than this limit, it bypasses the aggregator. Note that the backend enforces a limit of 50 KB on record size. If you set this beyond 50 KB, oversize records are rejected at the backend.

Default: 51200
Minimum: 64
Maximum (inclusive): 1048576

#### collection_max_count
The maximum number of items to pack into an PutRecords request. There should be normally no need to adjust this. To limit the time records spend buffering, look into [**record_max_buffered_time**](#record_max_buffered_time) instead.

Default: 500
Minimum: 1
Maximum (inclusive): 500

#### collection_max_size
The maximum amount of data to send with a PutRecords request. There should be normally no need to adjust this. To limit the time records spend buffering, look into [**record_max_buffered_time**](#record_max_buffered_time) instead.

Records larger than the limit are still sent, but not be grouped with others.

Default: 5242880
Minimum: 52224
Maximum (inclusive): 9223372036854775807

#### connect_timeout
The timeout (milliseconds) for establishing the TLS connections.

Default: 6000
Minimum: 100
Maximum (inclusive): 300000

##### custom_endpoint
Use a custom Amazon Kinesis or Amazon CloudWatch endpoint. This parameter is mostly for testing use. Note that this parameter does not accept protocols or paths, only host names or IP addresses. There is no way to disable TLS. The KPL always connects with TLS.

Expected pattern: `^([A-Za-z0-9-\\.]+)?$`

#### fail_if_throttled
The default is `false`. If `true`, throttled puts are not retried. The records that got throttled are failed immediately upon receiving the throttling error. This is useful if you want to react immediately to any throttling without waiting for the KPL to retry. For example, you can use a different hash key to send the throttled record to a backup shard.

If `false`, the KPL automatically retries throttled puts. The KPL performs backoff for shards that it has received throttling errors from, and avoids flooding them with retries. Note that records may fail from expiration if they get delayed for too long because of throttling. For more information, see [**record_ttl**](#record_ttl). 

#### log_level
The minimum level of logs. Messages below the specified level are not logged. Logs for the native KPL daemon show up on stderr.

Default: `info`
Expected pattern: `info|warning|error`

#### max_connections
The maximum number of connections to open to the backend. HTTP requests are sent in parallel over multiple connections. Setting this too high may impact latency and consume additional resources without increasing throughput.

Default: 4
Minimum: 1
Maximum (inclusive): 128

#### metrics_granularity
Controls the granularity of metrics that are uploaded to CloudWatch. Greater granularity produces more metrics. When `stream` is selected, per shard metrics are not uploaded; when `global` is selected, only the total aggregate for all streams and all shards are uploaded. Consider reducing the granularity if you're not interested in shard-level metrics, or if you have a large number of shards. If you only have 1 stream, select `global`; the global data will be equivalent to that for the stream. See the metrics documentation for details about each metric.

For example, when `shard` is selected, metrics are emitted with the stream name and shard ID as dimensions. On top of this, the same metric is also emitted with only the stream name dimension, and lastly, without the stream name. This means for a particular metric, 2 streams with 2 shards (each) produce 7 CloudWatch metrics, one for each shard, one for each stream, and one overall, all describing the same statistics, but at different levels of granularity.

Default: `shard`
Expected pattern: `global|stream|shard`

#### metrics_level
Controls the number of metrics that are uploaded to CloudWatch. See the metrics documentation for details about each metric.

`none` disables all metrics.

`summary` enables the following metrics: UserRecordsPut, KinesisRecordsPut, ErrorsByCode, AllErrors, BufferingTime.

`detailed` enables all remaining metrics.

Default: `detailed`
Expected pattern: `none|summary|detailed`

#### metrics_namespace
The namespace under which to upload metrics. If you have multiple applications running the KPL under the same AWS account, use a different namespace for each application. If you are also using the KCL, you may wish to use the application name you have configured for the KCL as the the namespace here. That way, both your KPL and KCL metrics show up under the same namespace.

Default: `KinesisProducerLibrary`
Expected pattern: `(?!AWS/).{1,255}`

#### metrics_upload_delay
The delay (in milliseconds) between each metrics upload. For testing only; there is no benefit in setting this lower or higher in production.

Default: 60000
Minimum: 1
Maximum (inclusive): 60000

#### min_connections
The minimum number of connections to keep open to the backend. There should be no need to increase this in general.

Default: 1
Minimum: 1
Maximum (inclusive): 16

#### port
Server port to connect to. This parameter is only useful with [**custom_endpoint**](#custom_endpoint).

Default: 443
Minimum: 1
Maximum (inclusive): 65535

#### rate_limit
Limits the maximum allowed put rate for a shard, as a percentage of the backend limits. The rate limit prevents the producer from sending data too fast to a shard. Such a limit is useful for reducing bandwidth and CPU cycle wastage from sending requests that you know are going to fail from throttling. Amazon Kinesis enforces limits on both the number of records and number of bytes per second. This setting applies to both.

The default value of 150% is chosen to allow a single producer instance to completely saturate the allowance for a shard. This is an aggressive setting. To reduce throttling errors rather than completely saturate the shard, consider reducing this setting.

Default: 150
Minimum: 1
Maximum (inclusive): 9223372036854775807

#### record_max_buffered_time
The maximum amount of time (milliseconds) that a record may spend being buffered before it gets sent. Records may be sent sooner than this depending on the other buffering limits. This setting provides coarse ordering among records: any two records are reordered by no more than twice this amount (assuming no failures and retries and equal network latency). 

The library makes a best effort to enforce this time, but cannot guarantee that it will be precisely met. In general, if the CPU is not overloaded, the library meets this deadline to within 10ms. Failures and retries can additionally increase the amount of time records spend in the KPL. If your application cannot tolerate late records, use the [**record_ttl**](#record_ttl) setting to drop records that do not get transmitted in time. Setting this too low can negatively impact throughput.

Default: 100
Maximum (inclusive): 9223372036854775807

#### record_ttl
The time-to-live setting on records (milliseconds). Records that do not get successfully put within the limit are failed. This setting is useful if your application cannot or does not wish to tolerate late records. Records still incur network latency after they leave the KPL, so take that into consideration when choosing a value for this setting.

If you do not wish to lose records and prefer to retry indefinitely, set [**record_ttl**](#record_ttl) to a large value like INT_MAX. This has the potential to cause head-of-line blocking if network issues or throttling occur. You can respond to such situations by using the metrics reporting functions of the KPL. You may also set [**fail_if_throttled**](#fail_if_throttled) to true to prevent automatic retries in case of throttling.

Default: 30000
Minimum: 100
Maximum (inclusive): 9223372036854775807

#### request_timeout
The maximum total time (milliseconds) elapsed between when you begin a HTTP request and receiving all of the response. If it goes over, the request is timed-out.

Note that a timed-out request may actually succeed at the backend. Retrying then leads to duplicates. Setting the timeout too low therefore increases the probability of duplicates.

Default: 6000
Minimum: 100
Maximum (inclusive): 600000

#### verify_certificate
A erification of the endpoint's certificate. Do not disable unless using [**custom_endpoint**](#custom_endpoint) for testing. Never disable this in production.The default is `true`.

#### credentials_refresh_delay
The interval (milliseconds) for refreshing credentials sent to the KPL. The default is 5000.

#### Configuration: kinesis_firehose
The following are `kinesis_firehose`-specific configuration parameters.

#### delivery_stream_name
The name of the delivery stream to which to put data.

#### region
The AWS Region of your stream. It should be in form `us-east-1` or `us-west-2`. For more information about supported regions, see [Regions and Endpoints][region]. The default is `nil`, which finds this value from the environment variable `AWS_REGION`.

#### append_new_line
Boolean. The default is `true`. If enabled, the plugin adds a newline character (`\n`) to each serialized record.  

#### retries_on_batch_request
Integer. The default is 3. The plugin puts multiple records to Amazon Kinesis Firehose in batches, using PutRecordBatch. A set of records in a batch may fail for reasons documented in the Amazon Kinesis Firehose API Reference. Failed records are retried **retries_on_batch_request** times. If a record fails all retries, an error log is emitted.

#### reset_backoff_if_success
Boolean. The default is `true`. If enabled, the next retry checks the number of succeeded records on the former batch request and resets the exponential backoff if there is any success. Because the batch request could be composed by requests across shards, simple exponential backoff for the batch request won't work in some cases.

#### batch_request_max_count
Integer. The default is 500. The max count for making batch requests from a record chunk. It can't exceed the default value because it is the API limit.

#### batch_request_max_size
Integer. The default is 4 * (1024 * 1024). The max size for making batch requests from a record chunk. It can't exceed the default value because it is the API limit.

#### http_proxy
The HTTP proxy for API calling. The default is `nil`.

#### endpoint
The API endpoint URL, for testing. The default is `nil`.

#### ssl_verify_peer
Boolean. Disable to verify the SSL connection for testing. The default is `true`.

#### debug
Boolean. Enable to debug an Amazon Kinesis Firehose API call. The default is `false`.

## Development
To launch the `fluentd` process with this plugin for development, run the following command:

    git clone https://github.com/awslabs/aws-fluent-plugin-kinesis.git
    cd aws-fluent-plugin-kinesis
    make # installs gems, downloads KPL .jar file, and extracts binaries
    bundle exec fluentd -c /path/to/fluent.conf

To run a benchmark, use the following command:
`make benchmark`

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
