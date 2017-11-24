require 'yaml'
require 'erubis'
require 'netaddr'
require 'deep_merge'
require 'digest/sha1'
require 'securerandom'

require './cloudformation/params.rb'
require './cloudformation/modules.rb'

namespace :cf do

  desc 'Turn a stack up'
  task :up, :env_name, :version do |t,args|
    version = args[:version]
    env_name = args[:env_name]

    Rake::Task['flush_cache'].invoke()

    Rake::Task['cf:launch'].invoke( 'network-%s' % env_name, version, 'network-%s' % env_name )
    cmd_wait = format('aws cloudformation wait stack-create-complete --stack-name network-%s-%s', env_name, version.gsub(/\./,'-'))
    LOG.debug('CMD(wait): %s' % cmd_wait)
    Rake::Task['cf:launch'].reenable
    system cmd_wait

    Rake::Task['flush_cache'].invoke()

    Rake::Task['cf:launch'].invoke( 'bastion-%s' % env_name, version, 'bastion-%s' % env_name )
    Rake::Task['cf:launch'].reenable
    Rake::Task['cf:launch'].invoke( 'workout-tracker-%s' % env_name, version, 'WT-%s' % env_name )
  end

  desc 'Turn down a stack'
  task :down, :env_name, :version do |t,args|
    version = args[:version]
    env_name = args[:env_name]

    cmd_del_wt = format('aws cloudformation delete-stack --stack-name WT-%s-%s', env_name, version.gsub(/\./,'-'))
    cmd_wait_wt = format('aws cloudformation wait stack-delete-complete --stack-name WT-%s-%s', env_name, version.gsub(/\./,'-'))
    cmd_del_bastion = format('aws cloudformation delete-stack --stack-name bastion-%s-%s', env_name, version.gsub(/\./,'-'))
    cmd_del_network = format('aws cloudformation delete-stack --stack-name network-%s-%s', env_name, version.gsub(/\./,'-'))

    system cmd_del_bastion
    system cmd_del_wt
    system cmd_wait_wt

    system cmd_del_network
  end

  desc 'Status'
  task :stats do
    cache = DevOps::Cache.new()

    creds = Aws::SharedCredentials.new()
    cft_client = Aws::CloudFormation::Client.new(
      region: ENV['AWS_DEFAULT_REGION'], credentials: creds
    )

    cache_key = "DescribeStacks"
    stacks = cache.cached_json(cache_key) do
      cft_client.describe_stacks().data.to_h.to_json
    end

    stacks['stacks'].each do |stack|
      pp stack
    end

  end

  desc 'Create the chef config.'
  task :mk_chef_config do |t, args|
    region = ENV['AWS_DEFAULT_REGION']
    inf_version = ENV['INF_VERSION']
    chef_version = ENV['CHEF_VERSION']

    p = ParamsProc.new({'region' => region})
    (elbs, elb_tags) = p.get_elbs_with_tags()

    v = {'tags' => {
        'Name' => 'ChefServer',
        'Role' => 'External',
        'Version' => chef_version
    }}

    elb_target = elb_tags['tag_descriptions'].select { |elb| elb['tags'].select { |t| v['tags'].select { |k, v| t['key'] == k && t['value'] == v }.size == 1 }.compact.size == v['tags'].size }.first
    chef_dns_name = elbs['load_balancer_descriptions'].select { |elb| elb['load_balancer_name'] == elb_target['load_balancer_name'] }.first['dns_name']

    input = File.read('knife.rb.erb')
    eruby = Erubis::Eruby.new(input)

    cfg = {
        :stack_version => chef_version,
        :chef_server_url => chef_dns_name.downcase
    }

    File.open(format('%s/.chef/knife-%s.rb', ENV['HOME'], chef_version), 'w') do |f|
      f.write eruby.result(cfg)
    end

    creds = Aws::SharedCredentials.new()
    s3_client = Aws::S3::Client.new(region: region, credentials: creds)

    r = s3_client.get_object(bucket: format('dev-central-%s', inf_version), key: 'chef-server/devops/bkroger.pem')
    File.open(format('%s/.chef/keys/bkroger-%s.pem', ENV['HOME'], chef_version), 'w') do |f|
      f.write r.body.read
    end
  end


    #net = NetAddr::CIDR.create(vpc['cidr'])
    #blocks = net.subnet(:Bits => 24)

    # describe_availability_zones
    #azs = ec2_client.describe_availability_zones()
    #pp azs

    #pp blocks
    #pp NetAddr::merge([blocks[0], blocks[1]], :Objectify => false)
    #sub1 = net.subnet(:Bits => 26, :NumSubnets => 1)
    #sub2 = net.subnet(:Bits => 23, :NumSubnets => 1)

    #pp sub1
    #pp sub2

    #blocks = net.subnet(:Bits => 24)
    #pp net.fill_in([blocks[0], blocks[2]])
    #pp 

  desc 'Launch a stack based on a profile PROFILE_NAME STACK_VERSION STACK_NAME'
  task :launch, :profile_name, :stack_version, :stack_name do |t, args|
    profile_name = args[:profile_name]
    region = ENV['AWS_DEFAULT_REGION'] || 'us-east-1'
    stack_version = args[:stack_version]

    ## Check to make sure the profile name exists.
    fs_profile_file = File.join('cloudformation', 'profiles', format('%s.yml', profile_name))
    LOG.debug(format('FS(profile_file): %s', fs_profile_file))

    unless File.exists? fs_profile_file
      LOG.fatal('Failed to find profile!')
      exit
    end

    yaml = YAML::load(File::read(fs_profile_file))

    ## Template
    fs_tpl_file = File.join('cloudformation', 'templates', format('%s.json', yaml['template']))
    if (!File.exists?(fs_tpl_file))
      LOG.fatal(format('Unable to find template JSON file: %s', fs_tpl_file))
      exit
    end

    stack_tpl = JSON::parse(File.read(fs_tpl_file))

    params = []
    if yaml.has_key?('modules')
      m = ModulesProc.new(yaml['modules'], stack_tpl)
      (stack_tpl, params) = m.compile
    end

    File.open("/tmp/stack.json", "w") do |f|
      f.puts(stack_tpl.to_json)
    end

    ## Params
    if yaml.has_key?('params')
      p = ParamsProc.new(yaml.merge({'region' => region}))
      yaml['params'] = p.compile()
    end

    #params.push({parameter_key: "StackVersion", parameter_value: stack_version.gsub(/\./, '-')})
    params.push({parameter_key: "StackVersion", parameter_value: stack_version})

    yaml['params'] ||= []

    yaml['params'].each do |k, v|
      val = if (v.class == Hash)
        v['value']
      else
        v
      end

      params.push({
        parameter_key: k,
        parameter_value: val
      })
    end

    File.open("/tmp/params.json", "w") do |f|
      f.puts(params.to_json)
    end

    stack_name = format('%s-%s', (args[:stack_name] == nil ? yaml['name'] : args[:stack_name]), stack_version.gsub(/\./, '-'))

    cache = DevOps::Cache.new()
    creds = Aws::SharedCredentials.new()
    cf_client = Aws::CloudFormation::Client.new(region: region, credentials: creds)

    cf_cache_key = format('cf_stacks-%s-%s', ENV['AWS_PROFILE'], ENV['AWS_DEFAULT_REGION'])
    stacks = cache.cached_json cf_cache_key do
      cf_client.describe_stacks().data.to_h.to_json
    end
    stack_exists = stacks['stacks'].select { |s| s['stack_name'] == stack_name }.compact.size == 0 ? false : true
    LOG.debug(format('Stack exists(%s): %s', stack_name, stack_exists))

    # exit

    tags = [{
      key: 'Owner',
      value: ENV['USER']
    },{
      key: 'Name',
      value: args[:stack_name]
    },{
      key: 'EnvName',
      value: 'dev'
    },{
      key: 'Version',
      value: stack_version
    }]

    if stack_exists
      LOG.debug(format('Updating stack'))
      cf_client.update_stack(
        tags: tags,
        parameters: params,
        stack_name: stack_name,
        capabilities: ["CAPABILITY_IAM"],
        template_body: stack_tpl.to_json
      )

    else
      LOG.debug(format('Creating stack'))

      ## Stack does not exist, create it.
      cf_client.create_stack({
        tags: tags,
        parameters: params,
        stack_name: stack_name,
        capabilities: ["CAPABILITY_IAM"],
        template_body: stack_tpl.to_json,
        disable_rollback: true,
        timeout_in_minutes: 30
      })

      cache.del_key cf_cache_key

    end

  end ## launch

end

