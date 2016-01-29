#
#  Copyright 2014-2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
#  Licensed under the Amazon Software License (the "License").
#  You may not use this file except in compliance with the License.
#  A copy of the License is located at
#
#  http://aws.amazon.com/asl/
#
#  or in the "license" file accompanying this file. This file is distributed
#  on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
#  express or implied. See the License for the specific language governing
#  permissions and limitations under the License.

.PHONY: install streams firehose producer dummer hello $(wildcard test/test_*.rb) $(wildcard test/**/test_*.rb)

all:
	bundle install
	bundle exec rake

install:
	bundle exec rake install:local

streams:
	bundle exec fluentd -c benchmark/streams.conf -vv

firehose:
	bundle exec fluentd -c benchmark/firehose.conf -vv

producer:
	bundle exec fluentd -c benchmark/producer.conf -vv

dummer:
	bundle exec dummer -c benchmark/dummer.conf

hello:
	echo Hello World | bundle exec fluent-cat --none dummy

$(wildcard test/test_*.rb) $(wildcard test/**/test_*.rb):
	bundle exec rake test TEST=$@
