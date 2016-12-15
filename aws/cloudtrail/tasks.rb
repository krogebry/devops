## 
# Rakefile for cloudtrail things.
##

namespace :ct do

  desc 'Return a list of CloudTrail targets.'
  task :list, :force_update do |t,args|
    t = Time.new()
    Log.debug('Processing stuff')
    Dir::glob(File.join(fs_tmp, "*.json")).each do |f|
      json = JSON::parse(File.read( f ))
      json['Records'].each do |r|
        ts = Time.parse(r['eventTime'])
        Log.debug(format('%s - %s - %s - %s', r['eventName'], r['userIdentity']['arn'], r['eventTime'], ts.localtime))
      end
    end
  end

  desc 'Pull logs down from s3 into local storage'
  task :pull, :trail_name do |t,args|
    db = DevOps::Utils::getDBConn()

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
          ## Go get the log file.
          s3_obj['content'] = ""

          Log.debug(format('Getting log file: %s', s3_obj['etag']))
          cache_key = format('s3_object_%s-%s-%s', ENV['AWS_PROFILE'], trail_name, s3_obj['etag'])
          gzip = Cache.get( cache_key ) do
            ro = ""
            s3_client.get_object({
              key: s3_obj['key'],
              bucket: trail_name
            }) do |chunk|
              ro << chunk
            end
            ro
          end

          gz = Zlib::GzipReader.new(StringIO.new(gzip)) 
          json = JSON::parse(gz.read)

          if(json.has_key?( 'Records' ))
            json['Records'].each do |r|
              if(r.has_key?( 'requestParameters' ) && r['requestParameters'] != nil)
                if(r['requestParameters'].has_key?( 'advancedOptions' ))
                  r['requestParameters'].delete('advancedOptions')
                end
              end

              if(r.has_key?( 'domainStatus' ) && r['domainStatus'] != nil)
                if(r['domainStatus'].has_key?( 'advancedOptions' ))
                  r['domainStatus'].delete('advancedOptions')
                end
              end

              if(r.has_key?( 'responseElements' ) && r['responseElements'] != nil)
                if(r['responseElements'].has_key?( 'domainStatus' ) && r['responseElements']['domainStatus'] != nil)
                  if(r['responseElements']['domainStatus'].has_key?( 'advancedOptions' ))
                    r['responseElements']['domainStatus'].delete('advancedOptions')
                  end
                end
              end

              if(r.has_key?( 'responseElements' ) && r['responseElements'] != nil)
                if(r['responseElements'].has_key?( 'domainConfig' ) && r['responseElements']['domainConfig'] != nil)
                  if(r['responseElements']['domainConfig'].has_key?( 'advancedOptions' ))
                    r['responseElements']['domainConfig'].delete('advancedOptions')
                  end
                end
              end

              db[:ct_logs_results].update_one({ 'requestID' => s3_obj['requestID'] }, s3_obj.merge( r ), { :upsert => true})
            end
          end

          db[:ct_logs].insert_one( s3_obj )

          s = 0.1 * rand( 10 )
          sleep( s )
        end
        Log.debug(format('Progress: %i/%i', i, objects['contents'].size))
        i+=1
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

