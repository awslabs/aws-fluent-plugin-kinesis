# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "fluent/plugin/version"

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-kinesis"
  spec.version       = FluentPluginKinesis::VERSION
  spec.author        = 'Amazon Web Services'
  spec.summary       = %q{Fluentd output plugin that sends events to Amazon Kinesis.}
  spec.homepage      = "https://github.com/awslabs/aws-kinesis-fluent-plugin"
  spec.license       = "Apache License, Version 2.0"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "test-unit-rr", "~> 1.0"
  spec.add_development_dependency "timecop"

  spec.add_dependency "fluentd", ">= 0.10.53", "< 0.11"
  spec.add_dependency "aws-sdk-core", "~> 2.0"
  spec.add_dependency "multi_json", "~> 1.0"
  spec.add_dependency "msgpack", ">= 0.5.8"
end
