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

require 'kinesis_producer'
require 'net/http'
require 'zip'

jar_version = "0.10.2"
jar_file = "amazon-kinesis-producer-#{jar_version}.jar"
jar_url = "https://search.maven.org/remotecontent?filepath=com/amazonaws/amazon-kinesis-producer/#{jar_version}/#{jar_file}"
cache_dir = Pathname.new(".cache")
cache_jar_file = cache_dir.join(jar_file)
binaries = KinesisProducer::Binary::Files.values

directory cache_dir

file cache_jar_file => [cache_dir] do |t|
  puts "Downloading #{jar_file}"
  download(jar_url, t.name)
end

binaries.each do |bin|
  file bin => [cache_jar_file] do |t|
    puts "Extracting #{bin} from #{jar_file}"
    unzip(cache_jar_file, bin)
    chmod 0755, bin
  end
end

task :binaries => binaries

task :clean do
  rm_rf cache_dir
  rm_rf File.dirname(File.dirname(binary))
end

def download(url, target)
  rm_f target
  uri = URI(url)
  Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |https|
    req = Net::HTTP::Get.new(uri.request_uri)
    https.request(req) do |res|
      open(target, 'wb') do |io|
        res.read_body do |chunk|
          io.write(chunk)
        end
      end
    end
  end
end

def unzip(zip_file, *targets)
  rm_f targets
  Zip::File.open(zip_file) do |z|
    z.each do |entry|
      if targets.include?(entry.name)
        mkdir_p File.dirname(entry.name)
        entry.extract(entry.name)
      end
    end
  end
end
