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

.PHONY: run run-td-agent-2.3.5 test test-td-agent-2.3.5 install $(wildcard test/test_*.rb) $(wildcard test/**/test_*.rb) benchmark benchmark-remote

all:
	bundle install

run:
	bundle exec fluentd -v

run-td-agent-2.3.5:
	RBENV_VERSION=2.1.10 BUNDLE_GEMFILE=./gemfiles/Gemfile.td-agent-2.3.5 bundle update
	RBENV_VERSION=2.1.10 BUNDLE_GEMFILE=./gemfiles/Gemfile.td-agent-2.3.5 bundle exec fluentd -v

test:
	bundle exec rake test

test-td-agent-2.3.5:
	RBENV_VERSION=2.1.10 BUNDLE_GEMFILE=./gemfiles/Gemfile.td-agent-2.3.5 bundle update
	RBENV_VERSION=2.1.10 BUNDLE_GEMFILE=./gemfiles/Gemfile.td-agent-2.3.5 bundle exec rake test

install:
	bundle exec rake install:local

$(wildcard test/test_*.rb) $(wildcard test/**/test_*.rb):
	bundle exec rake test TEST=$@

benchmark:
	bundle exec rake benchmark:local

benchmark-remote:
	bundle exec rake benchmark:remote
