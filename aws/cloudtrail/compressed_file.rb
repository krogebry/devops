class CTCompressedFile
  @queue = :files

  def self.perform(filename)
    gz_reader = Zlib::GzipReader.new(File.open(filename))
    json = JSON::parse(gz_reader.read())
    db = CloudTrailDB.new('localhost')
    json['Records'].each do |record|
      begin
        db.conn[:records].insert_one(record)

      rescue BSON::String::IllegalKey => e
        puts "IllegalKey: %s" % e

      rescue Mongo::Error::OperationFailure => e
        puts 'OperationFailure: %s' % e

      end
    end
    db.conn[:compressed_files].insert_one({ :filename => filename })
  end
end