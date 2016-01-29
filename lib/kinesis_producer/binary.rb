module KinesisProducer
  class Binary
    Dir = 'amazon-kinesis-producer-native-binaries'
    Files = {
      'linux'   => File.join(Dir, 'linux',   'kinesis_producer'),
      'osx'     => File.join(Dir, 'osx',     'kinesis_producer'),
      'windows' => File.join(Dir, 'windows', 'kinesis_producer.exe'),
    }
  end
end
