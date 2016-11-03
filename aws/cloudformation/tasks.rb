##
# CFT stuff
##
require 'yaml'
require 'digest/sha1'
require 'securerandom'

require './cloudformation/params.rb'

namespace :cf do

  task :mk_chef_config, :stack_version, :region_name do |t,args|
    version = args[:stack_version]
    
    creds = Aws::SharedCredentials.new()
    ec2_client = Aws::EC2::Client.new(region: args[:region_name], credentials: creds)
  end

  desc "Flush cache"
  task :flush_cache do |t,args|
    `rm -rf /tmp/cache/*`
  end

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

    if(yaml.has_key?( 'params' ))
      p = ParamsProc.new( yaml )
      yaml['params'] = p.compile() 
    end
    #pp args
    #exit

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

    yaml['params'] ||= []

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
      Log.debug('Stack already exists')

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



