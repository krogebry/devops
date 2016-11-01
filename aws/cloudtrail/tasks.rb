## 
# Rakefile for cloudtrail things.
##
namespace :cloudtrail do

  desc 'Do stuff'
  task :list, :force_update do |t,args|
    t = Time.new()

    fs_tmp = format('/tmp/cloud_trail/%s', t.strftime('%Y-%m-%d'))
    FileUtils::mkdir_p(fs_tmp)

    force_update(t, fs_tmp) if args[:force_update] == "1" 

    Log.debug('Processing stuff')

    Dir::glob(File.join(fs_tmp, "*.json")).each do |f|
      #Log.debug(f)
      json = JSON::parse(File.read( f ))
      #pp json
      json['Records'].each do |r|
        ts = Time.parse(r['eventTime'])
        Log.debug(format('%s - %s - %s - %s', r['eventName'], r['userIdentity']['arn'], r['eventTime'], ts.localtime))
      end
    end
  end

end

def force_update(t, fs_tmp)

  account_id = ENV['AWS_ACCOUNT_ID']
  region_name = ENV['AWS_REGION'] ||= 'us-east-1'
  ENV['AWS_PROFILE'] ||= 'sysco-adlm'

  creds = Aws::SharedCredentials.new()
  bucket_name = 'test0-logs'
  bucket_base_uri = format('test0/AWSLogs/%s/CloudTrail/%s/%i/%i/%s/', account_id, region_name, t.year, t.month, t.strftime( '%d'))

  s3_client = Aws::S3::Client.new(region: region_name, credentials: creds, signature_version: 'v4')
  objects = s3_client.list_objects_v2({
    bucket: bucket_name,
    prefix: bucket_base_uri
  })

  objects.contents.each do |o|
      #pp File::basename( o.key )
      basename = File::basename( o.key )
      Log.debug(format('Processing log: %s', basename))
      fs_tmp_file = format('%s/%s', fs_tmp, basename)
      if(!File.exists?(fs_tmp_file) && !File.exists?(fs_tmp_file.gsub( /(\.gz)$/,'' )))
        Log.debug('Getting file.')
        File.open fs_tmp_file, 'w' do |f|
          s3_client.get_object({
            key: o.key,
            bucket: bucket_name
          }) do |chunk|
            f.write chunk
          end
        end
        Log.debug('File write complete.')
        cmd_decompress = format('cd %s;gunzip %s', File::dirname(fs_tmp_file), fs_tmp_file)
        Log.debug(format('CMD(decompress): %s', cmd_decompress))
        system(cmd_decompress)
      end
  end
end
