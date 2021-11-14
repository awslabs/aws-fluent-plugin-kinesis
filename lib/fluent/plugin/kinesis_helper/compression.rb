require "stringio"
require "zlib"

class Stream < StringIO
  def initialize(*)
    super
    set_encoding "BINARY"
  end

  def close
    rewind;
  end
end

class Gzip
  def self.compress(string, level = Zlib::DEFAULT_COMPRESSION, strategy = Zlib::DEFAULT_STRATEGY)
    output = Stream.new
    gz = Zlib::GzipWriter.new(output, level, strategy)
    gz.write(string)
    gz.close
    output.string
  end

  def self.decompress(string)
    Zlib::GzipReader.wrap(StringIO.new(string), &:read)
  end
end
