##
# Recon some stuff
##

namespace :recon do

  desc "Recon s3"
  task :s3 do |t,args|
  end

  desc "Recon CT"
  task :cloud_trail do |t,args|
    c = Aws::CloudTrail::Client.new( credentials: Aws::SharedCredentials.new() )
    c_key = format("trails_%s_%s", ENV['AWS_DEFAULT_REGION'], ENV['AWS_PROFILE'])
    trails = Cache.cached_json( c_key ) do
      c.describe_trails.data.to_h.to_json
    end

    pp trails
  end

end
