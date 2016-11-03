##
# CFT stuff
##
require 'yaml'
require 'securerandom'

def get_filters( a )
  ro = []
  a.each do |k,v|
    ro.push({
      name: format('tag:%s', k),
      values: [v]
    })
  end
  ro
end

namespace :cf do

  desc 'Launch a stack based on a profile PROFILE_NAME STACK_NAME STACK_VERSION'
  task :launch, :profile_name, :stack_name, :stack_version do |t,args|
    profile_name = args[:profile_name]

    ## Check to make sure the profile name exists.
    fs_profile_file = File.join( 'cloudformation', 'profiles', format('%s.yml', profile_name ))
    Log.debug(format('FS(profile_file): %s', fs_profile_file))

    unless File.exists? fs_profile_file
      Log.fatal('Failed to find profile!')
      exit
    end

    yaml = YAML::load(File::read( fs_profile_file ))

    creds = Aws::SharedCredentials.new()
    cf_client = Aws::CloudFormation::Client.new(region: yaml['region'], credentials: creds)
    s3_client = Aws::S3::Client.new(region: yaml['region'], credentials: creds)
    ec2_client = Aws::EC2::Client.new(region: yaml['region'], credentials: creds)
    sns_client = Aws::SNS::Client.new(region: yaml['region'], credentials: creds)

    yaml['params'] ||= []

    ## Find any deps.
    yaml['params'].each do |k,v|
      Log.debug(format('%s - %s', k,v ))

      if(v.class == Hash && v.has_key?( 'type' ) && v.has_key?( 'tags' ))
        if(v['type'] == 'vpc')
          vpcs = ec2_client.describe_vpcs({ filters: get_filters( v['tags'] )})
          v['value'] = vpcs.vpcs.first['vpc_id']

        elsif(v['type'] == 'password')
          v['value'] = SecureRandom.hex

        elsif(v['type'] == 's3_bucket')
          bucket_name = format("%s-%s", v['tags']['Name'], v['tags']['Version'])

          #Log.debug(format('Bucket: %s', bucket_name))
          #buckets = s3_client.list_buckets()
          #bucket = buckets.buckets.select{|b| b.name == bucket_name }.first
          #if bucket == nil
            #Log.fatal(format('Unable to find bucket: %s', bucket_name))
            #exit
          #end

          v['value'] = bucket_name

        elsif(v['type'] == 'zones')
          v['value'] = v['zones'].join(',')

        elsif(v['type'] == 'sns_topic_arn')
          sns_topics = sns_client.list_topics()
          Log.debug(format('Looking for: %s', v['tags']['Name']))
          topic = sns_topics.topics.select{|t| t.topic_arn.match( /#{v['tags']['Name']}/ )}.first
          if topic == nil
            Log.fatal(format('Unable to find SNS topic: %s' % v['tags']['Name']))
            exit
          end
          v['value'] = topic.topic_arn

        elsif(v['type'] == 'subnets')
          v['tags'].each do |t|
            subnet = ec2_client.describe_subnets({ filters: get_filters( t )})
            v['value'] ||= []
            v['value'].push(subnet.subnets.first['subnet_id'])
          end
          v['value'] = v['value'].join(',')

        end
      end
    end

    stack_version = args[:stack_version]

    ## template
    fs_tpl_file = File.join( 'cloudformation', 'templates', format( '%s.json', yaml['template']))
    if(!File.exists?( fs_tpl_file ))
      Log.fatal(format('Unable to find template JSON file: %s', fs_tpl_file))
      exit
    end

    stack_tpl = JSON::parse(File.read( fs_tpl_file ))

    params = []
    params.push({ parameter_key: "StackVersion", parameter_value: stack_version })

    yaml['params'].each do |k,v|
      val = if(v.class == Hash)
        v['value']
      else
        v
      end

      params.push({
        parameter_key: k,
        parameter_value: val
      })
    end

    pp params

    stack_name = format('%s-%s', args[:stack_name], stack_version.gsub( /\./, '-' ))

    begin
      cf_client.describe_stacks({ stack_name: stack_name })
      ## Stack exists, update it.

    rescue Aws::CloudFormation::Errors::ValidationError => e
      Log.debug('Creating stack')

      ## Stack does not exist, create it.
      cf_client.create_stack({
        stack_name: stack_name,
        template_body: stack_tpl.to_json,
        parameters: params,
        disable_rollback: true,
        timeout_in_minutes: 30,
        capabilities: ["CAPABILITY_IAM"],
        tags: [{
          key: 'Owner',
          value: 'bkroger@thoughtworks.com'
        }]
      })

    end

  end ## launch
end



