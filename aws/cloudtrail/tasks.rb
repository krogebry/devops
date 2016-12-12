## 
# Rakefile for cloudtrail things.
##
namespace :ct do

  desc 'Return a list of CloudTrail targets.'
  task :list, :force_update do |t,args|
    t = Time.new()

    fs_tmp = format('/tmp/cloud_trail/%s', t.strftime('%Y-%m-%d'))
    FileUtils::mkdir_p(fs_tmp)

    force_update(t, fs_tmp) if args[:force_update] == "1" 

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

    cache_key = format('s3_%s-%s', ENV['AWS_PROFILE'], trail_name)
    objects = Cache.cached_json( cache_key ) do
      s3_client.list_objects_v2({
        bucket: trail_name,
        prefix: format('AWSLogs/%i/CloudTrail', ENV['AWS_ACCOUNT_ID'])
      }).data.to_h.to_json
    end

    f = File.open( '/tmp/ct_rows.json', 'w' )

    objects['contents'].each do |s3_obj|
      ## Check for existance of this key in local mongodb store
      r = db[:ct_logs].find( s3_obj )

      if r.count == 0
        ## Go get the log file.
        s3_obj['content'] = ""
        gzip = ""
        s3_client.get_object({
          key: s3_obj['key'],
          bucket: trail_name
        }) do |chunk|
          gzip << chunk
        end

        gz = Zlib::GzipReader.new(StringIO.new(gzip)) 
        s3_obj['content'] = JSON::parse(gz.read)

        ## Send the content of this file to local es store.
        db[:ct_logs].insert_one( s3_obj )

      else
        #Log.debug('no')
        row = r.first
        #json = JSON::parse(row['content'])
        #json['timestamp'] = json['digestStartTime']
        f.write(row['content'].to_json)
        f.write("\n")

      end
    end
    f.close

  end
end
