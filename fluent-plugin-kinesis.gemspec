# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fluent_plugin_kinesis/version'

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-kinesis"
  spec.version       = FluentPluginKinesis::VERSION
  spec.author        = 'Amazon Web Services'
  spec.summary       = %q{Fluentd output plugin that sends events to Amazon Kinesis.}
  spec.homepage      = "https://github.com/awslabs/aws-fluent-plugin-kinesis"
  spec.license       = "Amazon Software License"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.files         << "amazon-kinesis-producer-native-binaries.zip"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.extensions    = ["Rakefile"]
  spec.required_ruby_version = '>= 2.0.0'

  spec.add_dependency "fluentd", ">= 0.10.53", "< 0.13"
  spec.add_dependency "protobuf", ">= 3.5.5"
  spec.add_dependency "aws-sdk", "~> 2"
  spec.add_dependency "concurrent-ruby", "~> 1"
  spec.add_dependency "os", ">= 0.9.6"
  spec.add_dependency "rubyzip", ">= 1.0.0"

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "test-unit", ">= 3.0.8"
  spec.add_development_dependency "test-unit-rr", ">= 1.0.3"
  spec.add_development_dependency "pry", ">= 0.10.1"
  spec.add_development_dependency "pry-byebug", ">= 3.3.0"
  spec.add_development_dependency "net-empty_port", ">= 0.0.2"
  spec.add_development_dependency "dummer", ">= 0.4.0"
end
