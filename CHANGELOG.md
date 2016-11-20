# CHANGELOG

## 1.1.2

- Bug fix - Adjust credentials_provider for newer version of aws-ruby-sdk [#93](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/93)

## 1.1.1

- Bug fix - Fix incompatibility for AWS SDK 2.5 [#80](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/80)
- Bug fix - Fix wrong logic for batch request [#81](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/81)

## 1.1.0

- Feature - Derive stream name from fluentd tag for KPL [#67](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/67)
- Enhancement - Make http_proxy parameter secret [#64](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/64)
- Bug fix - Plugin incompatible with new fluentd release 0.14 [#70](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/70)
- Misc - Fix legacy test and reduce travis tests [#74](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/74)
- Misc - Some test, benchmark improvement [#74](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/74), [#75](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/75), [#76](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/76)

## 1.0.1

- Bug fix - Instance profile credentials expiring [#58](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/58)

## 1.0.0

To support Firehose and KPL, this was refactored and added more tests.

- Feature - Support Firehose
- Feature - Support KPL
- Feature - New parameters, such as formatter, data_key, reset_backoff_if_success, batch_request_max_count, batch_request_max_size, log_truncate_max_size

## 0.4.0

- Feature - Add option to ensure Kinesis Stream connection. [#35](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/35)
- Feature - Add option to support zlib compression. [#39](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/39)

Note: We introduced [Semantic Versioning](http://semver.org/) here.

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
