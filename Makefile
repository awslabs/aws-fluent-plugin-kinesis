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

.PHONY: test install benchmark benchmark-streams benchmark-producer hello $(wildcard test/test_*.rb) $(wildcard test/**/test_*.rb)

all:
	bundle install
	bundle exec rake binaries

test:
	bundle exec rake test

install:
	bundle exec rake install:local

benchmark: benchmark-streams benchmark-producer

benchmark-streams:
	bundle exec rake benchmark TYPE=streams

benchmark-producer:
	bundle exec rake benchmark TYPE=producer

hello:
	echo Hello World | bundle exec fluent-cat --none dummy

$(wildcard test/test_*.rb) $(wildcard test/**/test_*.rb):
	bundle exec rake test TEST=$@
