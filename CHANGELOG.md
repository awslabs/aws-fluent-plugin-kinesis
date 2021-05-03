# CHANGELOG

## 3.4.0

- Enhancement - Enable to monitor batch request failure and retries : [#150](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/150) [#211](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/211)
- Enhancement - Make sleep reliable by measuring actual slept time : [#162](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/162)
- Enhancement - Add td-agent 4.1.0 and Fluentd 1.12.3 to test cases

## 3.3.0

- Feature - Add web_identity_credentials configuration for IRSA : [#208](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/208) [#209](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/209)
- Enhancement - Remove strict gem pinning of google-protobuf to support Ruby 2.7 : [#199](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/199) [#206](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/206)
- Enhancement - Add td-agent v4 (4.0.1) and Fluentd 1.11.2 to test cases

## 3.2.3

- Enhancement - Add placeholder support for delivery_stream_name of kinesis_firehose : [#203](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/203) [#204](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/204)

## 3.2.2

- Enhancement - Make more strict gem pinning to deal with google-protobuf requiring Ruby 2.5+ : [#199](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/199)
- Bug - Fix MissingRegionError when http_proxy and endpoint_url are specified : [#197](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/197)

## 3.2.1

- Enhancement - Use Fluent::MessagePackFactory class methods instead of Mixin with Fluentd >= v1.8 : [#194](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/194) [#195](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/195)
- Enhancement - Add td-agent 3.5.1 and Fluentd 1.9.1 to test cases

## 3.2.0

- Feature - Add placeholder support for stream names to send records to multiple streams : [#165](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/165) [#174](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/174)
- Enhancement - Add sts_endpoint_url configuration parameter to support AWS STS regional endpoints : [#186](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/186)
- Enhancement - Add aws_ses_token configuration parameter to use IAM with MFA and directly provided temporary credentials : [#166](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/166)
- Dependency - Update gem dependency to Ruby 2.3.0+ and Fluentd 0.14.22+
- Bug - Fix dependency problem on AWS SDK with td-agent v3.4.1

## 3.1.0

- Feature - Add process_credentials configuration : [#178](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/178)

## 3.0.0

Plugin v3 is almost compatible with v2. You can use v3 with the same configuration as v2. For more details, please see [README](README.md).

- Enhancement - Use modularized AWS SDK v3 since fluent-plugin-s3 also supports it : [#152](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/152)
- Enhancement - Remove support for Fluentd v0.12 and use new Plugin API : [#156](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/156) (also fix [#133](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/133))
- Enhancement / Breaking change - Remove *chomp* method from internal formatter : [#142](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/142) [#144](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/144)
- Enhancement - Add *chomp_record* option for compatible format with plugin v2 : [#142](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/142)
- Bug - Fix undefined method error in flushing buffers : [#133](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/133)
- Bug - Fix dependency problem on AWS SDK : [#161](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/161)

## 2.1.1

- Bug - Fix require aws-sdk-core before requiring the aws related libraries [#140](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/140)

## 2.1.0

- Feature - Added sts_http_proxy parameter to assume_role_credentials configuration [#136](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/136)

## 2.0.1

- Bug - Fix AWS SDK conflict with s3 plugin [#131](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/131)

## 2.0.0

- Feature - Add `kinesis_streams_aggregated` ouput plugin [#107](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/107)
- Feature - Support fluentd worker model [#104](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/104)
- Feature - Support AWS SDK for Ruby v3 [#102](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/102)
- Enhancement - Refactor class design [#103](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/103)
- Enhancement - More configuration for AssumeRole [#63](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/63)
- Enhancement - Refactor credentials helper [#94](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/94)
- Enhancement - Revisit backoff logic [#69](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/69)
- Enhancement - Support compressing output [#98](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/98)
- Enhancement - Support nanosecond time_key format [#124](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/124)
- License - Move back to Apache License Version 2.0

## 1.3.0

- Feature - Log KPL stdout/err to logger [#129](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/129) [#130](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/130)

## 1.2.0

- Feature - Add reduce_max_size_error_message configuration [#127](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/127)
- Bug fix - Fix empty batch error [#125](https://github.com/awslabs/aws-fluent-plugin-kinesis/pull/125)

## 1.1.3

- Bug fix - Fix issues with fluentd 0.14.12 [#99](https://github.com/awslabs/aws-fluent-plugin-kinesis/issues/99)

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
