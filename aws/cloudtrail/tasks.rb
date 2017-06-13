require 'pp'
require 'json'
require 'zlib'
require 'mongo'
require 'resque'
require 'resque/tasks'

require './cloudtrail/instance.rb'
require './cloudtrail/compressed_file.rb'
require './cloudtrail/db.rb'
require './cloudtrail/redis.rb'

DATA_DIR = File.join('/', 'mnt', 'data')

if ENV['REDIS_HOSTNAME']
  Resque.redis = '%s:6379' % ENV['REDIS_HOSTNAME']
end

namespace :cloudtrail do

  desc 'Slurp some files'
  task :slurp, :hostname do |t,args|
    files = []

    hostname = args[:hostname].nil? ? 'localhost' : args[:hostname]

    db = CloudTrailDB.new(hostname)
    CloudTrailRedis.new(hostname)

    Log.debug('Gathering files from: %s' % DATA_DIR)
    file_list = Dir.glob(File.join(DATA_DIR, '**/*.gz'))
    Log.debug('Found %i files' % file_list.size)

    all_compressed_files = []
    db.conn[:compressed_files].find.each do |row|
      all_compressed_files.push(row[:filename])
    end

    Log.debug('Pulled %i records from the db' % all_compressed_files.size)
    
    file_list.each do |filename|
      #check = DB[:compressed_files].find({ :filename => filename })
      #files.push(filename) if check.count() == 0
      all_compressed_files.include?(filename) ? next : files.push(filename)
    end

    num_files = files.size
    Log.debug('Found %i files' % num_files)

    files.each do |filename|
      Resque.enqueue(CTCompressedFile, filename)
    end
  end

  desc 'snap'
  task :snap, :current_version, :new_version do |t,args|
    # cache = DevOps::Cache.new()
    creds = Aws::SharedCredentials.new()
    ec2_client = Aws::EC2::Client.new(region: 'us-east-1', credentials: creds)

    #instances = ec2_client.describe_instances()
    #pp instances

    ## ssh-keygen -f "/home/krogebry/.ssh/known_hosts" -R cloud0.krogebry.com
    ## update DNS for cloud0
    ## run s3 sync
    ## run dc
    ## run slurp
    ## wait for q's to clear
    ## (optional) backup and store in s3
    ## create AMI snap
    ## delete stack

    # current_version = '0.9.5'
    # new_version = '0.9.6'

    current_version = args[:current_version]
    new_version = args[:new_version]

    filters = [{
      name: 'tag:aws:cloudformation:logical-id',
      values: ['CTCompute']
    },{
      name: 'tag:Version',
      values: [current_version.gsub(/\./, '-')]
    }]
    res = ec2_client.describe_instances(filters: filters)
    instance = res.reservations[0].instances[0]
    instance_id = instance.instance_id

    image_filters = [{
      name: 'tag:Name',
      values: ['ct-compute']
    },{
      name: 'tag:Version',
      values: [new_version]
    }]
    res_images = ec2_client.describe_images(filters: image_filters)
    #pp res_images.images

    if res_images.images.empty?
      ## Create image
		  resp = ec2_client.create_image({
  		  name: "ct-compute-%s" % new_version,
  		  dry_run: false,
  		  no_reboot: false,
  		  instance_id: instance_id,
  		  block_device_mappings: [{
      	  virtual_name: "root",
      	  device_name: "/dev/xvda",
      	  ebs: {
        	  encrypted: false,
        	  volume_size: 8,
        	  volume_type: "gp2",
        	  delete_on_termination: true
      	  }
        },{
      	  virtual_name: "mongodb",
      	  device_name: "/dev/sdb",
      	  ebs: {
        	  iops: 1000,
        	  encrypted: true,
        	  volume_size: 100,
        	  volume_type: "io1",
        	  delete_on_termination: true
      	  }
    	  },{
      	  virtual_name: "data",
      	  device_name: "/dev/sdf",
      	  ebs: {
        	  iops: 1000,
        	  encrypted: true,
        	  volume_size: 100,
        	  volume_type: "io1",
        	  delete_on_termination: true
      	  }
        }],
		  })
      sleep 1
      ami_id = resp.image_id
    else
      ami_id = res_images.images[0].image_id
    end

    ## Tag image
    i = Aws::EC2::Image.new(ami_id)

    i.create_tags({
      tags: [{
        key: "Name",
        value: "ct-compute"
      },{
        key: "Version",
        value: new_version
      }]
    })
    Log.debug('Created tags for image')

    Log.info('Waiting for snapshots')
    sleep 5

    ## Tag the blocks.
    i.block_device_mappings.each do |block|
      next if block.ebs.snapshot_id.nil?
      snap = Aws::EC2::Snapshot.new(block.ebs.snapshot_id)
      snap.create_tags({
        tags: [{
          key: "Name",
          value: "ct-compute"
        },{
          key: "Version",
          value: new_version
        }]
      })
    end
    Log.debug('Tagged block devices')

    Log.debug("State: %s" % i.state)
  end

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

  desc 'Find human interactions on the AWS UI console'
  task :find_human_console_interactions do
    #ts_start = Time.new.to_f()

    epoc_start = "2017-05-22T00:00:00Z"
    epoc_end = "2017-05-23T00:00:00Z"

    queries = {}

    queries['human_consul_actions'] = {
        "awsRegion" => "us-west-2",
        "userAgent" => "signin.amazonaws.com",
        "userIdentity.type" => "IAMUser",
        "$and" => [
            {"eventTime" => {"$gt" => epoc_start}},
            {"eventTime" => {"$lt" => epoc_end}}
        ],
        "recipientAccountId" => "123"
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

  desc "Find interesting things"
  task :find_interesting_things do
    epoc_start = "2017-05-22T00:00:00Z"
    epoc_end = "2017-05-23T00:00:00Z"

    queries = {}

    queries['interesting_delete_actions'] = {
        "awsRegion" => "us-west-2",
        "eventName" => {
           "$in" => ['DeleteSnapshot', 'DeleteDBSnapshot', 'DeleteHealthCheck']
        },
        "recipientAccountId" => "123"
    }

    queries['interesting_iam_actions'] = {
        "awsRegion" => "us-west-2",
        "eventName" => {
            "$in" => ['DeleteGroupPolicy', 'DisassociateIamInstanceProfile']
        },
        "recipientAccountId" => "123"
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

  desc "Breakdown human actions"
  task :breakdown_human_actions do
    queries = {}
    queries['human_actions_by_event_type'] = {
        '_id' => '$eventName',
        'count' => { '$sum' => 1}
    }
    queries.each do |coll_name, query|
      aggregate = DB[:human_consul_actions].aggregate([
        {"$group" => query},
        {"$out": coll_name.to_s}
      ])
      aggregate.count()
    end
  end

  desc "Create event name map"
  task :create_event_name_mapping do
    queries = {}
    queries['event_names'] = {'_id' => '$eventName'}
    queries.each do |coll_name, query|
      aggregate = DB[:records].aggregate([
                                                          {"$group" => query},
                                                          {"$out": coll_name.to_s}
                                                      ])
      aggregate.count()
    end
  end

  desc "Find asg"
  task :find_asg, :asg_name do |t,args|
    queries = {}

    hostname = 'localhost'
    db = CloudTrailDB.new(hostname)

    Log.debug("ASGName: %s" % args[:asg_name])

    queries['mod_asg'] = {
        "awsRegion" => "us-west-2",
        "eventName" => "UpdateAutoScalingGroup",
        #"eventName" => "DeleteLoadBalancerListeners",
        "requestParameters.autoScalingGroupName" => args[:asg_name]
    }

    pp queries

    queries.each do |coll_name, query|
      aggregate = db.conn[:records].aggregate([
        {"$match" => query},
        {"$out": coll_name.to_s}
      ])
      aggregate.count()
    end
  end

  desc "Find elb"
  task :find_elb, :elb_name do |t,args|
    queries = {}

    hostname = 'localhost'
    db = CloudTrailDB.new(hostname)

    Log.debug("ELBName: %s" % args[:elb_name])

    queries['mod_elb'] = {
      "awsRegion" => "us-west-2",
      "eventName" => "ModifyLoadBalancerAttributes",
      #"eventName" => "DeleteLoadBalancerListeners",
      "requestParameters.loadBalancerName" => args[:elb_name]
    }

    pp queries

    queries.each do |coll_name, query|
      aggregate = db.conn[:records].aggregate([
        {"$match" => query},
        {"$out": coll_name.to_s}
      ])
      aggregate.count()
    end
  end

  desc "Find run instance"
  task :find_run_instance, :instance_id do |t,args|
    ts_start = Time.new.to_f()
    queries = {}
    Log.debug("InstanceId: %s" % args[:instance_id])
    queries['run_instance'] = {
      "awsRegion" => "us-west-2",
      "responseElements.instancesSet.items.instanceId" => args[:instance_id],
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
