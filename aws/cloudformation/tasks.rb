##
# CFT stuff
##
require 'yaml'
require 'erubis'
require 'digest/sha1'
require 'securerandom'

require './cloudformation/params.rb'

namespace :cf do

  desc 'Create the chef config.'
  task :mk_chef_config, :stack_version, :region_name do |t,args|
    version = args[:stack_version]

    #yaml = YAML::load(File::read( fs_profile_file ))
    p = ParamsProc.new({ 'region' => args[:region_name] })

    (elbs, elb_tags) = p.get_elbs_with_tags()
    #pp elb_tags

    v = { 'tags' => {
      'Name' => 'ChefServer',
      'Role' => 'External',
      'Version' => version
    }}

    elb_target = elb_tags['tag_descriptions'].select{|elb| elb['tags'].select{|t| v['tags'].select{|k,v| t['key'] == k && t['value'] == v}.size == 1 }.compact.size == v['tags'].size }.first
    chef_dns_name = elbs['load_balancer_descriptions'].select{|elb| elb['load_balancer_name'] == elb_target['load_balancer_name'] }.first['dns_name']
    #pp dns_name

    input = File.read('knife.rb.erb')
    eruby = Erubis::Eruby.new(input) 

    cfg = {
      :stack_version => version,
      :chef_server_url => chef_dns_name.downcase
    }
    #puts eruby.result(binding())
    #puts eruby.result( cfg )
    File.open(format('%s/.chef/knife-%s.rb', ENV['HOME'], version), 'w') do |f|
      f.write eruby.result( cfg )
    end

    creds = Aws::SharedCredentials.new()
    s3_client = Aws::S3::Client.new(region: args[:region_name], credentials: creds)

    r = s3_client.get_object(bucket: format('dev-central-%s', version), key: 'chef-server/devops/bkroger.pem')
    File.open(format('%s/.chef/keys/bkroger-%s.pem', ENV['HOME'], version), 'w') do |f|
      f.write r.body.read
    end
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



