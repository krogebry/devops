require 'pp'
require 'json'
require 'zlib'
require 'mongo'
require 'resque'
require 'resque/tasks'

#require './cloudtrail/instance.rb'
#require './cloudtrail/compressed_file.rb'
#require './cloudtrail/db.rb'
#require './cloudtrail/redis.rb'

#DATA_DIR = File.join('/', 'mnt', 'data')
DATA_DIR = File.join('/', 'mnt', 'SecureDisk', 'cloudtrail')

#if ENV['REDIS_HOSTNAME']
  #Resque.redis = '%s:6379' % ENV['REDIS_HOSTNAME']
#end

begin
  if ENV['USE_AWS_CREDS'] == true
    creds = Aws::SharedCredentials.new()
    S3Client = Aws::S3::Client.new(credentials: creds)
    SQSClient = Aws::SQS::Client.new(credentials: creds)
    DynamoClient = Aws::DynamoDB::Client.new(credentials: creds)

  else
    S3Client = Aws::S3::Client.new()
    SQSClient = Aws::SQS::Client.new()
    DynamoClient = Aws::DynamoDB::Client.new()

  end

rescue => e
  Log.fatal('Failed to create dynamodb client: %s' % e)
  exit

end

def clean_json( json )
  json.each do |k,v|
    if v.class == Hash
      if v.keys.size == 0
        json[k] = nil
      else
        v = clean_json( v ) 
      end
    end
    json[k] = nil if v == ""
  end
  json
end

def nap( msg='Napping' )
  timer = rand(0.5) + rand(0.3)
  Log.debug(format('%s %.3f', msg, timer))
  sleep( timer )
end

namespace :cloudtrail do

	desc 'Proc SQS'
  task :proc_sqs do |t,args|
    queue_url = format('https://sqs.us-east-1.amazonaws.com/%s/tt_data_sync', ENV['AWS_ACCOUNT_ID'])
    messages = SQSClient.receive_message( queue_url: queue_url )
    messages.messages.each do |message|
      body = JSON::parse message.body
      i = 0
      num_files = body['files'].size
      body['files'].each do |filename|
        gz_reader = Zlib::GzipReader.new(File.open(filename))
        json = JSON::parse(gz_reader.read())

        i_records = 0
        num_records = json['Records'].size
        batch = []
        i_batch = 0
        num_per_batch = 20

        json['Records'].each do |r|
          r['r_id'] = format('%s-%s', r['requestID'], r['eventID'])
          #r = clean_json(r)
          batch.push({ put_request: { item: clean_json(r) }})

          if i_batch >= num_per_batch
            Log.debug('Flushing')
            begin
              DynamoClient.batch_write_item({
                request_items: {
                  'tattletrail' => batch
                }
              })

            rescue Aws::DynamoDB::Errors::ValidationException => e
              pp batch
              exit

            end

            batch = []
            i_batch = 0
            nap
          end

          #DynamoClient.put_item({
            #item: r,
            #table_name: 'tattletrail'
          #})
          #nap

          i_batch += 1
          i_records += 1
          Log.debug(format('%i / %i', i_records, num_records))
        end
        i += 1
        Log.debug(format('%i / %i', i, num_files))
      end

      SQSClient.delete_message(
        queue_url: queue_url,
        receipt_handle: message.receipt_handle
      )
      sleep( 1 )

    end
  end

  desc 'Slurp some files'
  task :slurp, :hostname do |t,args|
    files = []

    num_files_per_queue = 100

    hostname = args[:hostname].nil? ? 'localhost' : args[:hostname]

    #db = CloudTrailDB.new(hostname)
    #CloudTrailRedis.new(hostname)

    Log.debug('Gathering files from: %s' % DATA_DIR)
    file_list = Dir.glob(File.join(DATA_DIR, '**/*.gz'))
    Log.debug('Found %i files' % file_list.size)

    while file_list.size > 0
    	message = {'files' => file_list.pop( num_files_per_queue )}
      SQSClient.send_message(
      	queue_url: format('https://sqs.us-east-1.amazonaws.com/%s/tt_data_sync', ENV['AWS_ACCOUNT_ID']),
      	message_body: message.to_json
      )
    end

    # all_compressed_files = []
    # db.conn[:compressed_files].find.each do |row|
    #   Log.debug('pushed %s' % row[:filename])
    #   all_compressed_files.push(row[:filename])
    # end

    # Log.debug('Pulled %i records from the db' % all_compressed_files.size)

    #file_list.each do |filename|
      #check = db.conn[:compressed_files].find({ :filename => filename })
      #files.push(filename) if check.count() == 0
      # all_compressed_files.include?(filename) ? next : files.push(filename)
    #end

    #num_files = files.size
    #Log.debug('Found %i files' % file_list.size)

    #files.each do |filename|
      #Resque.enqueue(CTCompressedFile, filename, hostname)
    #end
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

    endhighlight
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
