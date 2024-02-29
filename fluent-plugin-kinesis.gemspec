# coding: utf-8
#
# Copyright 2014-2017 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You
# may not use this file except in compliance with the License. A copy of
# the License is located at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# or in the "license" file accompanying this file. This file is
# distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
# ANY KIND, either express or implied. See the License for the specific
# language governing permissions and limitations under the License.

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fluent_plugin_kinesis/version'

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-kinesis"
  spec.version       = FluentPluginKinesis::VERSION
  spec.author        = 'Amazon Web Services'
  spec.summary       = %q{Fluentd output plugin that sends events to Amazon Kinesis.}
  spec.homepage      = "https://github.com/awslabs/aws-fluent-plugin-kinesis"
  spec.license       = "Apache-2.0"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.required_ruby_version = '>= 2.4.2'

  spec.add_dependency "fluentd", ">= 0.14.22", "< 2"

  # This plugin is sometimes used with s3 plugin, so watch out for conflicts
  #   https://rubygems.org/gems/fluent-plugin-s3
  # Exclude v1.5 to avoid aws-sdk dependency problem due to this issue
  #   https://github.com/aws/aws-sdk-ruby/issues/1872
  # Exclude aws-sdk-kinesis v1.4 to avoid aws-sdk-core dependency problem with td-agent v3.1.1
  #   NoMethodError: undefined method `event=' for #<Seahorse::Model::Shapes::ShapeRef:*>
  #   https://github.com/aws/aws-sdk-ruby/commit/03d60f9d3d821e645bd2a3efca066f37350ef906#diff-c69f15af8ea3eb9ab152659476e04608R401
  #   https://github.com/aws/aws-sdk-ruby/commit/571c2d0e5ff9c24ff72893a08a74790db591fb57#diff-a55155f04aa6559460a0814e264eb0cdR43
  # Exclude aws-sdk-kinesis v1.14 to avoid aws-sdk-core dependency problem with td-agent v3.4.1
  #   LoadError: cannot load such file -- aws-sdk-core/plugins/transfer_encoding.rb
  #   https://github.com/aws/aws-sdk-ruby/commit/bb61ed0a2fabc6b1f90b757f13f37d5aeae48d8a#diff-b493e941d32289cd2df7eebc3fc5be2cR26
  #   https://github.com/aws/aws-sdk-ruby/commit/e26577d2a426a4be79cd2d9edc1a4a4176e388ba#diff-10f50e27b30c3dc522b3c25db5782e2e
  spec.add_dependency "aws-sdk-kinesis", "~> 1", "!= 1.4", "!= 1.5", "!= 1.14"
  # Exclude aws-sdk-firehose v1.9 to avoid aws-sdk-core dependency problem with td-agent v3.2.1
  #   LoadError: cannot load such file -- aws-sdk-core/plugins/endpoint_discovery.rb
  #   https://github.com/aws/aws-sdk-ruby/commit/85d8538a62255e58d9e176ee524a9f94354b51a0#diff-d51486091a10ada65b308b7f45966af1R18
  #   https://github.com/aws/aws-sdk-ruby/commit/7c9584bc6473100df9aec9333ab491ad4faeeca8#diff-be94f87e58e00329a6c0e03e43d5c292
  # Exclude aws-sdk-firehose v1.15 to avoid aws-sdk-core dependency problem with td-agent v3.4.1
  #   LoadError: cannot load such file -- aws-sdk-core/plugins/transfer_encoding.rb
  #   https://github.com/aws/aws-sdk-ruby/commit/bb61ed0a2fabc6b1f90b757f13f37d5aeae48d8a#diff-d51486091a10ada65b308b7f45966af1R26
  #   https://github.com/aws/aws-sdk-ruby/commit/e26577d2a426a4be79cd2d9edc1a4a4176e388ba#diff-10f50e27b30c3dc522b3c25db5782e2e
  spec.add_dependency "aws-sdk-firehose", "~> 1", "!= 1.5", "!= 1.9", "!= 1.15"

  spec.add_dependency "google-protobuf", "~> 3"

  spec.add_development_dependency "bundler", ">= 1.10"
  spec.add_development_dependency "rake", ">= 10.0"
  spec.add_development_dependency "test-unit", ">= 3.0.8"
  spec.add_development_dependency "test-unit-rr", ">= 1.0.3"
  spec.add_development_dependency "pry", ">= 0.10.1"
  spec.add_development_dependency "pry-byebug", ">= 3.3.0"
  spec.add_development_dependency "pry-stack_explorer", ">= 0.4.9.2"
  spec.add_development_dependency "net-empty_port", ">= 0.0.2"
  spec.add_development_dependency "mocha", ">= 1.1.0"
  spec.add_development_dependency "webmock", ">= 1.24.2"
  spec.add_development_dependency "fakefs", ">= 0.8.1"
end
