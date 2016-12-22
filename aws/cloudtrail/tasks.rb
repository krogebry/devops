## 
# Rakefile for cloudtrail things.
##

require './cloudtrail/resque.rb'
require 'resque'
require 'resque/tasks'

#Resque.redis = "redis:6379"
Resque.redis = "127.0.0.1:6379"

namespace :ct do

  desc "Report"
  task :report do |t,args|
    action = "DescribeLoadBalancers"
  end

  desc "Tail the current events."
  task :tail do |t,args|
    require 'time'

    user_map = {
      'nmjl147' => 'jlittle'
    }

    db = DevOps::Utils::getDBConn()
    rows = db[:ct_logs_results].find({}).sort({ eventTime: -1 }).limit( 100 )
    rows.each do |r|
      #pp r
      t = Time.parse( r['eventTime'] )
			dhms = [60,60,24].reduce([(Time.new.to_f - t.localtime.to_f)]) { |m,o| m.unshift(m.shift.divmod(o)).flatten }
      username = user_map.has_key?( r['userIdentity']['userName'] ) ? user_map[r['userIdentity']['userName']] : r['userIdentity']['userName']
      puts format("%s (-%id:%ih:%im)\t%s\t%s\t%s", t, dhms[0], dhms[1], dhms[2], username, r['eventSource'], r['eventName'] )
    end
  end

  desc "Index db"
  task :index do |t,args|
    db = DevOps::Utils::getDBConn()
    db[:ct_logs_results].indexes.create_one({ eventTime: 1 })
    db[:ct_logs_results].indexes.create_one({ requestId: 1 })
  end

  desc 'Return a list of CloudTrail targets.'
  task :list, :force_update do |t,args|
  end

  desc 'Pull logs down from s3 into local storage'
  task :pull, :trail_name do |t,args|
    db = DevOps::Utils::getDBConn()
    #Resque.redis = "redis:6379"

    trail_name = args[:trail_name]

    creds = Aws::SharedCredentials.new()
    s3_client = Aws::S3::Client.new(credentials: creds, signature_version: 'v4')

    truncated = true
    continuation_token = nil

    while truncated == true
      cache_key = format('s3_%s-%s-%s', ENV['AWS_PROFILE'], trail_name, continuation_token)
      objects = Cache.cached_json( cache_key ) do
        s3_client.list_objects_v2({
          bucket: trail_name,
          prefix: format('AWSLogs/%i/CloudTrail/', ENV['AWS_ACCOUNT_ID']),
          continuation_token: continuation_token
        }).data.to_h.to_json
      end

      truncated = objects['is_truncated'] 
      continuation_token = objects['next_continuation_token']

      i = 0

      objects['contents'].each do |s3_obj|
        ## Check for existance of this key in local mongodb store

        r = db[:ct_logs].find( s3_obj )
        if r.count == 0
          Resque.enqueue(DevOps::CloudTrailProc, s3_obj.to_json, trail_name)
        end
      end

    end
  end

  desc "Dump to ES."
  task :dump_to_es do
    i = 0
    buffer = []
    max_lines = 1000

    db = DevOps::Utils::getDBConn()
    rows = db[:ct_logs_results].find()
    rows.each do |row|
      buffer.push( row )

      if(i >= max_lines)
        f = File.open( '/tmp/ct_rows.json', 'w' )
        buffer.each do |b|
          b.delete '_id'
          f.write(b.to_json)
          f.write("\n")
        end
        f.close

        cmd_update_es = format('nc localhost 5000 < /tmp/ct_rows.json')
        system(cmd_update_es)
        i = 0
        buffer = []
        Log.debug('Sleeping')
        sleep 5
      end

      i+=1
    end

  end
end

