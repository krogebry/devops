## COUNT=1 QUEUE=files rake resque:workers
require 'pp'
require 'json'
require 'zlib'
require 'mongo'
require 'resque'
require 'resque/tasks'

Mongo::Logger.logger.level = ::Logger::FATAL
DB = Mongo::Client.new('mongodb://mongodb:27017', database: "cloudtrail")
DB[:compressed_files].indexes.create_one({ filename: 1 }, { unique: true })
DB[:records].indexes.create_one({ requestID: 1, eventID: 1 }, { unique: true })
DB[:records].indexes.create_one({ eventTime: 1 })
DB[:records].indexes.create_one({ eventName: 1 })
DB[:records].indexes.create_one({ awsRegion: 1 })

Resque.redis = 'redis:6379'

class CTCompressedFile
  @queue = :files

  def self.perform(filename)
    #Log.debug('Processing: %s' % filename)
    gz_reader = Zlib::GzipReader.new(File.open(filename))
    json = JSON::parse(gz_reader.read())
    json['Records'].each do |record|
      check = DB[:records].find({ requestID: record['requestID'], eventID: record['eventID'] })
      if check.count() == 0
        DB[:records].insert_one(record)
      end
    end
    #Log.debug('Processed %i records' % json['Records'].size)
    DB[:compressed_files].insert_one({ :filename => filename })
  end
end

namespace :cloudtrail do

  desc 'Slurp some files'
  task :slurp do |t,args|
    i = 0
    queue_flush_i = 0
    queue_max_entries = 100

    root_dir = File.join('/', 'mnt', 'SecureDisk')
    #root_dir = "/mnt/SecureDisk/cloudtrail/us-west-2/2017/03/"
    #root_dir = "/mnt/SecureDisk/cloudtrail/us-west-2/2017/02/"
    files = []

    Log.debug("Gathering files")
    Dir.glob(File.join(root_dir, "**/*.gz")).each do |filename|
      check = DB[:compressed_files].find({ :filename => filename })
      files.push(filename) if check.count() == 0
    end

    num_files = files.size
    Log.debug("Found %i files" % num_files)

    queue = []

    files.each do |filename|
      Resque.enqueue(CTCompressedFile, filename)
    end
  end

  desc "Report"
  task :report, :rebuild do |t,args|
    ts_start = Time.new.to_f()
    rebuild = args[:rebuild] == "true" ? true : false
    queries = {}

    queries[:security_group_changes] = {
        "awsRegion" => "us-west-2",
        "$and" => [
          { "userAgent" => { "$not" => { "$eq" => "cloudformation.amazonaws.com" }}},
          { "userAgent" => { "$not" => { "$eq" => "aws-sdk-go/1.4.6 (go1.7.3; darwin; amd64)"}}},
          { "userAgent" => { "$not" => { "$eq" => "aws-sdk-go/1.4.6 (go1.7.3; linux; amd64)"}}},
          { "userAgent" => { "$not" => { "$eq" => "APN/1.0 HashiCorp/1.0 Terraform/0.8.1"}}}
        ],
        "eventName" => "AuthorizeSecurityGroupIngress",
        "requestParameters.cidrIp" => "0.0.0.0/0"
    }

    queries[:delete_nat_gateway] = {
                                    "awsRegion" => "us-west-2",
                                    "userAgent" => { "$not" => { "$eq" => "cloudformation.amazonaws.com" }},
                                    "eventName" => "DeleteNatGateway"
                                }

    if rebuild
      Log.debug("Rebuilding")

      queries.each do |coll_name, query|
        DB[coll_name].drop()

        aggregate = DB[:records].aggregate([
                                 {"$match" => query},
                                 {"$out": coll_name.to_s}
                             ])
        aggregate.count()
      end
    end

    records = DB[:security_group_changes].find()

    records.each do |record|
      pp record
    end

    Log.debug('Found %i logs' % records.count())

    Log.debug('Runtime: %.2f' % (Time.new.to_f - ts_start))
  end
end
