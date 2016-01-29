# Deprecated: Fluent Plugin for Amazon Kinesis v0.4

Please see [the latest README](https://github.com/awslabs/aws-fluent-plugin-kinesis/blob/master/README.md).

## Overview

[Fluentd](http://fluentd.org/) output plugin
that sends events to [Amazon Kinesis](https://aws.amazon.com/kinesis/).

Also, there is a documentation on [Fluentd official site](http://docs.fluentd.org/articles/kinesis-stream).

## Installation

This fluentd plugin is available as the `fluent-plugin-kinesis` gem from RubyGems.

    gem install fluent-plugin-kinesis

Or you can install this plugin for [td-agent](https://github.com/treasure-data/td-agent) as:

    fluent-gem install fluent-plugin-kinesis

If you would like to build by yourself and install, please see the section below.
Your need [bundler](http://bundler.io/) for this.

In case of using with Fluentd:
Fluentd will be also installed via the process below.

    git clone https://github.com/awslabs/aws-fluent-plugin-kinesis.git
    cd aws-fluent-plugin-kinesis
    bundle install
    rake build
    rake install

Also, you can use this plugin with td-agent:
You have to install td-agent before installing this plugin.

    git clone https://github.com/awslabs/aws-fluent-plugin-kinesis.git
    cd aws-fluent-plugin-kinesis
    bundle install
    rake build
    fluent-gem install pkg/fluent-plugin-kinesis

Or just download specify your Ruby library path.
Below is the sample for specifying your library path via RUBYLIB.

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

## Configuration

Here are items for Fluentd configuration file.

To put records into Amazon Kinesis,
you need to provide AWS security credentials.
If you provide aws_key_id and aws_sec_key in configuration file as below,
we use it. You can also provide credentials via environment variables as
AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY.  Also we support IAM Role for
authentication. Please find the [AWS SDK for Ruby Developer Guide](http://docs.aws.amazon.com/AWSSdkDocsRuby/latest/DeveloperGuide/ruby-dg-setup.html)
for more information about authentication.
We support all options which AWS SDK for Ruby supports.

### type

Use the word 'kinesis'.

### stream_name

Name of the stream to put data.

### aws_key_id

AWS access key id.

### aws_sec_key

AWS secret key.

### role_arn

IAM Role to be assumed with [AssumeRole](http://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRole.html).
Use this option for cross account access.

### external_id

A unique identifier that is used by third parties when
[assuming roles](http://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRole.html) in their customers' accounts.
Use this option with `role_arn` for third party cross account access.
For detail, please see [How to Use an External ID When Granting Access to Your AWS Resources to a Third Party](http://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-user_externalid.html).

### region

AWS region of your stream.
It should be in form like "us-east-1", "us-west-2".
Refer to [Regions and Endpoints in AWS General Reference](http://docs.aws.amazon.com/general/latest/gr/rande.html#ak_region)
for supported regions.

### ensure_stream_connection

When enabled, the plugin checks and ensures a connection to the stream you are using by [DescribeStream](http://docs.aws.amazon.com/kinesis/latest/APIReference/API_DescribeStream.html) and throws exception if it fails. Enabled by default.

### http_proxy

Proxy server, if any.
It should be in form like "http://squid:3128/"

### random_partition_key

Boolean. If true, the plugin uses randomly generated
partition key for each record. Note that this parameter
overrides *partition_key*, *partition_key_expr*,
*explicit_hash_key* and *explicit_hash_key_expr*.

### partition_key

A key to extract partition key from JSON object.

### partition_key_expr

A Ruby expression to extract partition key from JSON object.
We treat your expression as below.

    a_proc = eval(sprintf('proc {|record| %s }', YOUR_EXPRESSION))
    a_proc.call(record)

You should write your Ruby expression that receives input data
as a variable 'record', process it and return it. The returned
value will be used as a partition key. For use case example,
see 'Configuration examples' part.

### explicit_hash_key

A key to extract explicit hash key from JSON object.
Explicit hash key is hash value used to explicitly
determine the shard the data record is assigned to
by overriding the partition key hash.

### explicit_hash_key_expr

A Ruby expression to extract explicit hash key from JSON object.
Your expression will be treat in the same way as we treat partition_key_expr.

### order_events

Boolean. By enabling it, you can strictly order events in Amazon Kinesis,
according to arrival of events. Without this, events will be coarsely ordered
based on arrival time. For detail,
see [Using the Amazon Kinesis Service API](http://docs.aws.amazon.com/kinesis/latest/dev/kinesis-using-api-java.html#kinesis-using-api-defn-sequence-number).

Please note that if you set *detach_process* or *num_threads greater than 1*,
this option will be ignored.

### detach_process

Integer. Optional. This defines the number of parallel processes to start.
This can be used to increase throughput by allowing multiple processes to
execute the plugin at once. This cannot be used together with **order_events**.
Setting this option to > 0 will cause the plugin to run in a separate
process. The default is 0.

### num_threads

Integer. The number of threads to flush the buffer. This plugin is based on
Fluentd::BufferedOutput, so we buffer incoming records before emitting them to
Amazon Kinesis. You can find the detail about buffering mechanism [here](http://docs.fluentd.org/articles/buffer-plugin-overview).
Emitting records to Amazon Kinesis via network causes I/O Wait, so parallelizing
emitting with threads will improve throughput.

This option can be used to parallelize writes into the output(s)
designated by the output plugin. The default is 1.
Also you can use this option with *detach_process*.

### retries_on_putrecords

Integer, default is 3. When **order_events** is false, the plugin will put multiple
records to Amazon Kinesis in batches using PutRecords. A set of records in a batch
may fail for reasons documented in the Kinesis Service API Reference for PutRecords.
Failed records will be retried **retries_on_putrecords** times. If a record
fails all retries an error log will be emitted.

### use_yajl

Boolean, default is false.
In case you find error `Encoding::UndefinedConversionError` with multibyte texts, you can avoid that error with this option.

### zlib_compression

Boolean, default is false.
Zlib compresses the message data blob.
Each zlib compressed message must remain within megabyte in size.

### debug

Boolean. Enable if you need to debug Amazon Kinesis API call. Default is false.

## Configuration examples

Here are some configuration examles.
Assume that the JSON object below is coming to with tag 'your_tag'.

    {
      "name":"foo",
      "action":"bar"
    }

### Simply putting events to Amazon Kinesis with a partition key

In this example, simply a value 'foo' will be used as partition key,
then events will be sent to the stream specified in 'stream_name'.

    <match your_tag>
    type kinesis

    stream_name YOUR_STREAM_NAME

    aws_key_id YOUR_AWS_ACCESS_KEY
    aws_sec_key YOUR_SECRET_KEY

    region us-east-1

    partition_key name
    </match>

### Using partition_key_expr to add specific prefix to partition key

In this example, we add partition_key_expr to the example above.
This expression adds string 'some_prefix-' to partition key 'name',
then partition key finally will be 'some_prefix-foo'.

With specifying parition_key and parition_key_expr both,
the extracted value for partition key from JSON object will be
passed to your Ruby expression as a variable 'record'.

    <match your_tag>
    type kinesis

    stream_name YOUR_STREAM_NAME

    aws_key_id YOUR_AWS_ACCESS_KEY
    aws_sec_key YOUR_SECRET_KEY

    region us-east-1

    partition_key name
    partition_key_expr 'some_prefix-' + record
    </match>

### Using partition_key_expr to extract a value for partition key

In this example, we use only partition_key_expr to extract
a value for partition key. It will be 'bar'.

Specifying partition_key_expr without partition_key,
hash object that is converted from whole JSON object will be
passed to your Ruby expression as a variable 'record'.

    <match your_tag>
    type kinesis

    stream_name YOUR_STREAM_NAME

    aws_key_id YOUR_AWS_ACCESS_KEY
    aws_sec_key YOUR_SECRET_KEY

    region us-east-1

    partition_key_expr record['action']
    </match>

### Improving throughput to Amazon Kinesis

The achievable throughput to Amazon Kinesis is limited to single-threaded
PutRecord calls if **order_events** is set to true. By setting **order_events**
to false records will be sent to Amazon Kinesis in batches. When operating in
this mode the plugin can also be configured to execute in parallel.
The **detach_process** and **num_threads** configuration settings control
parallelism.

Please note that **order_events** option will be ignored if you choose to
use either **detach_process** or **num_threads**.

In case of the configuration below, you will spawn 2 processes.

    <match your_tag>
    type kinesis

    stream_name YOUR_STREAM_NAME
    region us-east-1

    detach_process 2

    </match>

You can also specify a number of threads to put.
The number of threads is bound to each individual processes.
So in this case, you will spawn 1 process which has 50 threads.

    <match your_tag>
    type kinesis

    stream_name YOUR_STREAM_NAME
    region us-east-1

    num_threads 50
    </match>

Both options can be used together, in the configuration below,
you will spawn 2 processes and 50 threads per each processes.

    <match your_tag>
    type kinesis

    stream_name YOUR_STREAM_NAME
    region us-east-1

    detach_process 2
    num_threads 50
    </match>

## Related Resources

* [Amazon Kinesis Developer Guide](http://docs.aws.amazon.com/kinesis/latest/dev/introduction.html)  
