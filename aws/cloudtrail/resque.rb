## 
# Rakefile for cloudtrail things.
##

#Log = DevOps::Logger.new(STDOUT)
#Cache = DevOps::Cache.new

module DevOps
  class CloudTrailProc
    @queue = :cloudtrail

    def self.perform( s3_obj, trail_name )
      s3_obj = JSON::parse( s3_obj )
      db = DevOps::Utils::getDBConn()
      creds = Aws::SharedCredentials.new()
      s3_client = Aws::S3::Client.new(credentials: creds, signature_version: 'v4')

      r = db[:ct_logs].find( s3_obj )
      return if r.count != 0

      ## Go get the log file.
      s3_obj['content'] = ""

      cache_key = format('s3_object_%s-%s-%s', ENV['AWS_PROFILE'], trail_name, s3_obj['etag'])
      gzip = ::Cache.get( cache_key ) do
        Log.debug(format('Getting log file: %s', s3_obj['etag']))
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
        #i = 0
        #total = json['Records'].size
        Log.debug(format('Processing %i rows', json['Records'].size))
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

          #Log.debug('Inserting row')
          #start = Time.new.to_f
          db[:ct_logs_results].update_one({ 'requestID' => s3_obj['requestID'] }, s3_obj.merge( r ), { :upsert => true})
          #Log.debug(format('%i / %i ( %.2f )', i, total, Time.new.to_f - start))
          #i+=1
        end ## Each record

      end ## If records

      db[:ct_logs].insert_one( s3_obj )
      sleep rand(10)

    end ## perform

  end ## CloudTrailProc
end ## DevOps
