# CHANGELOG

## 0.3.6

- **Cross account access support**: Added support for cross account access for Amazon Kinesis stream. With this update, you can put reocrds to streams those are owned by other AWS account. This feature is achieved by [AssumeRole](http://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRole.html).

## 0.3.5

- **1MB record size limit**: Increased record size limit from 50KB to 1MB due to [Amazon Kinesis improvement.](http://aws.amazon.com/jp/about-aws/whats-new/2015/06/amazon-kinesis-announces-put-pricing-change-1mb-record-support-and-the-kinesis-producer-library/)
- **Switching IAM user support**: Added support for [shared credential file](http://docs.aws.amazon.com/ja_jp/AWSSdkDocsRuby/latest/DeveloperGuide/prog-basics-creds.html#creds-specify-provider).

## 0.3.4

- **Multi-byte UTF-8 support**: We now support multi-byte UTF-8 by using *use_yajl* option.

## 0.3.3

- **Security improvements**: Disabled logging `aws_key_id` and `aws_sec_key` into log file.

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
