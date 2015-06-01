# CHANGELOG

## 0.3.2

- **http_proxy support**: Added HTTP proxy support.

## 0.3.1

- **Fluentd v0.12 support**: We now support Fluentd v0.12.

## 0.3.0

- **Throughput improvement**: Added support for [PutRecords API](http://docs.aws.amazon.com/kinesis/latest/APIReference/API_PutRecords.html) by default.
- **Bug fix**: Removed redundant Base64 encoding of data for each Kinesis record emitted. Applications consuming these records will need to be updated accordingly.

## 0.2.0

- **Partition key randomization**: Added support for partition key randomization.
- **Throughput improvements**: Added support for spawning additional processes and threads to increase throughput to Amazon Kinesis.
- **AWS SDK for Ruby V2**: Added support for [AWS SDK for Ruby V2](https://github.com/aws/aws-sdk-core-ruby).

## 0.1.0

- Release on Github
