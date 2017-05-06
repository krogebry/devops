require 'pp'
require 'json'
require 'zlib'
require 'mongo'
require 'resque'
require 'resque/tasks'
#require './cloudtrail/instance.rb'

if(false)
Mongo::Logger.logger.level = ::Logger::FATAL
DB = Mongo::Client.new('mongodb://mongodb:27017', database: "cloudtrail")
DB[:compressed_files].indexes.create_one({ filename: 1 }, { unique: true })
DB[:records].indexes.create_one({ requestID: 1, eventID: 1 }, { unique: true })
DB[:records].indexes.create_one({ eventTime: 1 })
DB[:records].indexes.create_one({ eventName: 1 })
DB[:records].indexes.create_one({ awsRegion: 1 })
Resque.redis = 'redis:6379'
end


class CTCompressedFile
  @queue = :files

  def self.perform(filename)
    #Log.debug('Processing: %s' % filename)
    gz_reader = Zlib::GzipReader.new(File.open(filename))
    json = JSON::parse(gz_reader.read())
    json['Records'].each do |record|
      begin
        DB[:records].insert_one(record)

      rescue BSON::String::IllegalKey => e
        puts "IllegalKey: %s" % e

      rescue Mongo::Error::OperationFailure => e
        puts 'OperationFailure: %s' % e

      end
    end
    #Log.debug('Processed %i records' % json['Records'].size)
    DB[:compressed_files].insert_one({ :filename => filename })
  end
end

namespace :cloudtrail do

  desc 'audit'
  task :audit do |t,args|
    cache = DevOps::Cache.new()
    creds = Aws::SharedCredentials.new()
    ec2_client = Aws::EC2::Client.new(region: 'us-west-2', credentials: creds)

    addresses_key = 'eip_addresses'
    addresses = cache.cached_json(addresses_key) do
      filters = [{
                   name: "domain",
                   values: ["vpc"]
               }]
      ec2_client.describe_addresses(filters: filters).data.to_h.to_json
    end

    #pp addresses

    cache_key = 'ec2_instances'
    #cache.del_key(cache_key)
    instance_data = cache.cached_json(cache_key) do
      ec2_client.describe_instances(filters:[{
        name: 'instance-state-name',
        values: ['running']
      }]).data.to_h.to_json
    end
    #pp instances['reservations'][0].keys

    #num_instances = 0

    report = []

    instance_data['reservations'].each do |r|
      #num_instances += r['instances'].size
      r['instances'].each do |instance|
        #next if instance['instance_id'] != 'i-005dac566034b2abe'
        #puts instance.to_json
        i = EC2Instance.new(instance)
        rating = i.rate
        report.push({
            :rating => rating,
            :instance_id => instance['instance_id']
        })
      end
    end

    report.sort!{|a,b| a[:rating] <=> b[:rating]}
    #pp report
    report.each do |r|
      Log.info('%s - %s' % [r[:rating], r[:instance_id]])
    end

    #Log.debug('NumInstance: %s' % num_instances)
  end

  desc 'Slurp some files'
  task :slurp do |t,args|
    root_dir = File.join('/', 'mnt', 'SecureDisk')
    files = []

    Log.debug("Gathering files")
    file_list = Dir.glob(File.join(root_dir, "**/*.gz"))
    Log.debug('Found %i files' % file_list.size)

    file_list.each do |filename|
      check = DB[:compressed_files].find({ :filename => filename })
      files.push(filename) if check.count() == 0
    end

    num_files = files.size
    Log.debug('Found %i files' % num_files)

    files.each do |filename|
      Resque.enqueue(CTCompressedFile, filename)
    end
  end

  desc "Find run instance"
  task :find_run_instance, :instance_id do |t,args|
    ts_start = Time.new.to_f()
    queries = {}

    Log.debug("InstanceId: %s" % args[:instance_id])

    queries['run_instance'] = {
      "awsRegion" => "us-west-2",
      #"RequestId" => "14e51b16-5aa7-4688-91c1-5078b8a68ae5",
      "responseElements.instancesSet.items.instanceId" => args[:instance_id],
      #"responseElements.instancesSet.items" => {
        #"$elemMatch" => { "instanceId" => args[:instance_id] }
      #},
      "eventName" => "RunInstances"
    }

    pp queries

    queries.each do |coll_name, query|
      aggregate = DB[:records].aggregate([
        {"$match" => query},
        {"$out": coll_name.to_s}
      ])
      aggregate.count()
    end
  end

  desc "Find stack delete"
  task :find_stack_del, :stack_name do |t,args|
    ts_start = Time.new.to_f()
    rebuild = args[:rebuild] == "true" ? true : false
    queries = {}
    Log.debug("Stack: %s" % args[:stack_name])
    queries['delete_stack_report'] = {
      "awsRegion" => "us-west-2",
      "requestParameters.stackName" => /.*#{args[:stack_name]}.*/,
      "eventName" => "DeleteStack"
    }
    pp queries
    queries.each do |coll_name, query|
      aggregate = DB[:records].aggregate([
        {"$match" => query},
        {"$out": coll_name.to_s}
      ])
      aggregate.count()
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
