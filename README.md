# Fluent Plugin for Amazon Kinesis

## Overview

[Fluentd](http://fluentd.org/) output plugin 
which sends events to [Amazon Kinesis](https://aws.amazon.com/kinesis/).

## Installation

This project has not been published in rubygems.org at this time, 
so you have to build and install by yourself.
Your need [bundler](http://bundler.io/) to install.

In case of using with Fluentd:
Fluentd will be also installed via the process below.

    git clone https://github.com/awslabs/aws-fluent-plugin-kinesis.git
    cd aws-fluent-plugin-kinesis
    bundle install
    rake build
    rake install

Also, you can use this plugin with [td-agent](https://github.com/treasure-data/td-agent):
You have to install td-agent before installing this plugin.

    git clone https://github.com/awslabs/aws-fluent-plugin-kinesis.git
    cd aws-fluent-plugin-kinesis
    bundle install
    rake build
    fluent-gem install pkg/fluent-plugin-kinesis

Or just download specify your Ruby libpary path.
Below is the sample for specifying your library path via RUBYLIB.

    git clone https://github.com/awslabs/aws-fluent-plugin-kinesis.git
    cd aws-fluent-plugin-kinesis
    bundle install
    export RUBYLIB=$RUBYLIB:/path/to/aws-fluent-plugin-kinesis/lib

## Dependencies

 * Ruby 1.9.3+
 * Fluentd 0.10.43+

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
for more infomation about authentication.
We support all options which AWS SDK for Ruby supports.

### type

Use the word 'kinesis'.

### stream_name

Name of the stream to put data.

### aws_key_id

AWS access key id. 

### aws_sec_key

AWS secret key. 

### region

AWS region of your stream. 
It should be in form like "us-east-1", "us-west-2".
Refer to [Regions and Endpoints in AWS General Reference](http://docs.aws.amazon.com/general/latest/gr/rande.html#ak_region) 
for supported regions.

### partition_key

A key to extract partition key from JSON object.

### partition_key_expr

A Ruby expression to extract partition key from JSON object. 
We treat your expression as below. 

    a_proc = eval(sprintf('proc {|record| %s }', YOUR_EXPRESSION))
    a_proc.call(record)

You should write your Ruby expression which receives input data 
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

In this example, simpley a value 'foo' will be used as partition key,
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
the extracted value for partition key from JSON object will be passed to
your Ruby expression as a variable 'record'.

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
hash object which is converted from whole JSON object will be
passed to your Ruby expression as a variable 'record'.

    <match your_tag>
    type kinesis

    stream_name YOUR_STREAM_NAME

    aws_key_id YOUR_AWS_ACCESS_KEY
    aws_sec_key YOUR_SECRET_KEY

    region us-east-1

    partition_key_expr record['action']
    </match>

## Related Resources

* [Amazon Kinesis Developer Guide](http://docs.aws.amazon.com/kinesis/latest/dev/introduction.html)  
