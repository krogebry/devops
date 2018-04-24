# DBConnector for the CloudTrail Mongodb data set
class CloudTrailDB
  attr_accessor :conn
  def initialize(hostname = 'localhost')
    Mongo::Logger.logger.level = ::Logger::FATAL
    # local_ip = `curl http://169.254.169.254/2016-09-02/meta-data/local-ipv4/`.chomp
    # local_ip = '172.30.3.126'
    # local_ip = 'localhost'
    @conn = Mongo::Client.new(
      format('mongodb://%s:27017' % hostname ),
      database: 'cloudtrail'
    )
  end

  def build_indexes
    @conn[:compressed_files].indexes.create_one({ key: 1 }, { unique: true })
    @conn[:records].indexes.create_one({ requestID: 1, eventID: 1 }, { unique: true })
    @conn[:records].indexes.create_one({ eventTime: 1 })
    @conn[:records].indexes.create_one({ eventName: 1 })
    @conn[:records].indexes.create_one({ awsRegion: 1 })
  end
end
