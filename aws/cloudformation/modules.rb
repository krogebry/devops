
class ModulesProc
  @cache
  @config
  @params
  @s3_client
  @ec2_client
  @elb_client
  @sns_client

  @stack_tpl
  @stack_params

  def initialize(yaml, stack_tpl)
    @config = yaml
    @stack_tpl = stack_tpl

    @stack_params = []

    @cache = DevOps::Cache.new
  end

  def set_param( k, v )
    if v.class == Array
      v = v.join ','
    end

    @stack_params.push({
      parameter_key: k,
      parameter_value: v
    })
  end

  def get_param( param_name )
    @stack_params.select{|k,v| k[:parameter_key] == param_name }.first[:parameter_value]
  end

  def load_module( module_name )
    fs_module_file = File.join('cloudformation', 'templates', 'modules', format('%s.json' % module_name))
    if !File.exists? fs_module_file
      Log.debug(format('Module file not found: %s', fs_module_file))
      raise Exception.new()
    end
    Log.debug(format('Loading module: %s', fs_module_file))
    JSON::parse(File.read(fs_module_file))
  end

  def load_script( module_name )
    fs_module_file = File.join('cloudformation', 'templates', 'scripts', format('%s.sh' % module_name))
    if !File.exists? fs_module_file
      Log.debug(format('Module file not found: %s', fs_module_file))
      raise Exception.new()
    end
    Log.debug(format('Loading module: %s', fs_module_file))

    ro = []
    File.read(fs_module_file).each_line do |l|
      ro.push({"Fn::Sub" => l})
    end
    {"Fn::Join" => ["\n", ro]}
  end

  def merge_module( module_name )
    mod_json = load_module( module_name )

    @stack_tpl["Parameters"] = @stack_tpl['Parameters'].deep_merge(mod_json['Parameters'])

    if (mod_json.has_key?('Resources'))
      @stack_tpl['Resources'] = @stack_tpl['Resources'].deep_merge(mod_json['Resources'])
    end

    return unless mod_json.has_key?('ConfigSets')

    lcs = @stack_tpl['Resources'].select { |r_name, r_info| r_info["Type"] == "AWS::AutoScaling::LaunchConfiguration" }
    lcs.each do |lc_name, lc_info|
      stack_tpl['Resources'][lc_name]['Metadata']['AWS::CloudFormation::Init'].merge!(mod_json['ConfigSets'])
      ## Check for user data
      new_user_data = []
      @stack_tpl['Resources'][lc_name]['Properties']['UserData']['Fn::Base64']['Fn::Join'][1].each do |r|
        if (r.class == Hash)
          if (r.keys[0] == "DevOpsMod")
            Log.debug(format('Injecting user data for mod'))
            mod_json["UserData"].each do |udr|
              new_user_data.push(udr)
            end
          else
            new_user_data.push(r)
          end
        else
          new_user_data.push(r)
        end
      end
      @stack_tpl['Resources'][lc_name]['Properties']['UserData']['Fn::Base64']['Fn::Join'][1] = new_user_data
    end
  end

  def compile()
    @config.each do |m|
      if m.class == String
        Log.debug('module is a string')
        merge_module(m)

      elsif m.class == Hash
        Log.debug('module is a hash')
        if m.has_key?('type')
          begin
            self.send( m['type'], m )
          rescue NoMethodError => e
            Log.fatal(format('Unknown method error: %s - %s', m['type'], e))
            pp e.backtrace
            exit
          rescue => e
            Log.fatal(format('Unknown error: %s', e ))
            pp e.backtrace
            exit
          end
        end

      else
        Log.debug('module is an unknown type ')
      end
    end
    [@stack_tpl, @stack_params]
  end

  def deep_copy( hash )
    Marshal.load(Marshal.dump(hash))
  end

  def get_stack_by_filters( filters )
    creds = Aws::SharedCredentials.new()
    cf_client = Aws::CloudFormation::Client.new(credentials: creds)

    sel_filters = filters.map{|f| { 'key' => f.keys[0], 'value' => f.values[0] }}

    cache_key = 'cf_stacks'
    stacks = @cache.cached_json( cache_key ) do
      cf_client.list_stacks(stack_status_filter: ['CREATE_COMPLETE', 'UPDATE_COMPLETE']).data.to_h.to_json
    end

    stacks['stack_summaries'].each do |summary|
      cache_key = format('cf_stacks_%s', summary['stack_name'])
      stack_info = @cache.cached_json( cache_key ) do
        cf_client.describe_stacks(stack_name: summary['stack_name']).data.to_h.to_json
      end

      found_tags = 0
      stack_info['stacks'].first['tags'].each do |tag_set|
        if sel_filters.include? tag_set
          found_tags += 1
        end
      end
      Log.debug(format( 'Found tags: %i', found_tags ))
      return stack_info['stacks'].first if found_tags == filters.size
    end
    return nil
  end

  def get_stack_resources( stack_name )
    creds = Aws::SharedCredentials.new()
    cf_client = Aws::CloudFormation::Client.new(credentials: creds)
    cache_key = format('cf_stack_resources_%s', stack_name)
    resources = @cache.cached_json( cache_key ) do
      cf_client.describe_stack_resources(stack_name: stack_name).data.to_h.to_json
    end
    return resources
  end

  def get_stack_resource( stack_name, resource_name )
    creds = Aws::SharedCredentials.new()
    cf_client = Aws::CloudFormation::Client.new(credentials: creds)
    cache_key = format('cf_stack_resource_%s_%s', stack_name, resource_name)
    resource = @cache.cached_json( cache_key ) do
      cf_client.describe_stack_resource(stack_name: stack_name, logical_resource_id: resource_name).data.to_h.to_json
    end
    return resource
  end

  def ecs_service( m_config )
    json = load_module('ecs-service')    

    stack = get_stack_by_filters([
      { 'Name' => m_config['params']['cluster_name'] },
      { 'EnvName' => m_config['params']['cluster_env'] },
      { 'Version' => m_config['params']['cluster_version'] }
    ])

    ecs_cluster = get_stack_resource( stack['stack_name'], 'ECSCluster' )
    ecs_cluster_name = ecs_cluster['stack_resource_detail']['physical_resource_id']
    set_param('ECSCluster', ecs_cluster_name)

    container_def = json['Resources']['TaskDefinition']['Properties']['ContainerDefinitions'].first

    container_defs = []

    if m_config['params']['load_balancer']
      json['Resources']['EcsALB']['Properties']['Type'] = m_config['params']['load_balancer']['type'] if m_config['params']['load_balancer'].has_key?( 'type' )
      json['Resources']['EcsALB']['Properties']['Scheme'] = m_config['params']['load_balancer']['scheme'] if m_config['params']['load_balancer'].has_key?( 'scheme' )

      json['Resources']['ALBListener']['Properties']['Port'] = m_config['params']['load_balancer']['port'] if m_config['params']['load_balancer'].has_key?( 'port' )

      if m_config['params']['load_balancer'].has_key?( 'subnets' )
        json['Resources']['EcsALB']['Properties']['Subnets'] = { "Ref" => m_config['params']['load_balancer']['subnets'] }
      end

      if m_config['params']['load_balancer']['scheme'] == 'internal'
        json['Resources']['EcsALB']['Properties'].delete( 'SecurityGroups' )
        json['Resources']['ALBListener']['Properties']['Protocol'] = 'TCP'

        json['Resources']['EcsTargetGroup']['Properties']['Port'] = m_config['params']['load_balancer']['port']
        json['Resources']['EcsTargetGroup']['Properties']['Protocol'] = 'TCP'
        json['Resources']['EcsTargetGroup']['Properties']['HealthCheckProtocol'] = 'TCP'

        json['Resources']['EcsTargetGroup']['Properties'].delete( 'Matcher' )
        json['Resources']['EcsTargetGroup']['Properties'].delete( 'HealthCheckPath' )
      else
        json['Resources']['EcsALB']['Properties']['SecurityGroups'] = m_config['params']['load_balancer']['security_groups'].map{|sg_name| { "Ref" => sg_name }}
      end
    end

    m_config['params']['containers'].each do |container|
      c_def = deep_copy( container_def )
      c_def['Cpu'] = container['cpu']
      c_def['Memory'] = container['memory']

      c_def['Name'] = container['name']
      c_def['Image'] = format('%s.dkr.ecr.%s.amazonaws.com/%s', ENV['AWS_ACCOUNT_ID'], ENV['AWS_DEFAULT_REGION'], container['image'])

      if container['listener']
        c_def['PortMappings'][0]['ContainerPort'] = container['listener']
        json['Resources']['Service']['Properties']['LoadBalancers'][0]['ContainerPort'] = container['listener']
      end

      if container['environment']
        container['environment'].each do |k,v|
          c_def['Environment'].push({
            'Name' => k,
            'Value' => v
          })
        end
      end

      container_defs.push( c_def )
      json['Resources']['Service']['Properties']['LoadBalancers'][0]['ContainerName'] = container['name']
    end

    json['Resources']['TaskDefinition']['Properties']['ContainerDefinitions'] = container_defs

    @stack_tpl['Resources'] = @stack_tpl['Resources'].deep_merge(json['Resources'])
    @stack_tpl['Parameters'] = @stack_tpl['Parameters'].deep_merge(json['Parameters'])
  end

  def ecs_cwt_capacity( m_config )
    json = load_module('ecs-cwt-capacity')    

    alarms = json['Resources'].select{|k,v| v['Type'] == 'AWS::CloudWatch::Alarm'}
    policies = json['Resources'].select{|k,v| v['Type'] == 'AWS::AutoScaling::ScalingPolicy'}

    policies.each do |policy_name, policy_config|
      policy_config['Properties']['AutoScalingGroupName'] = { 'Ref' => m_config['params']['asg_name'] }
    end

    alarms.each do |alarm_name, alarm_config|
      alarm_config['Properties']['Dimensions'][0]['Value'] = { 'Ref' => m_config['params']['ecs_cluster_name'] }
    end

    @stack_tpl['Resources'] = @stack_tpl['Resources'].deep_merge(json['Resources'])
  end

  def r53( m_config )
    json = load_module('r53')

    #lbs = @stack_tpl['Resources'].select{|k,v| v['Type'] == 'AWS::ElasticLoadBalancingV2::LoadBalancer'}

    creds = Aws::SharedCredentials.new()
    route53 = Aws::Route53::Client.new(credentials: creds)

    cache_key = format('r53_%s', m_config['params']['domain_name'])
    zones = @cache.cached_json( cache_key ) do
      route53.list_hosted_zones_by_name({ dns_name: m_config['params']['domain_name'] }).data.to_h.to_json
    end
    zone_id = zones['hosted_zones'].first['id'].split('/')[-1]
    Log.debug(format('ZoneId: %s', zone_id))

    json['Resources']['DNSEntry']['Properties']['HostedZoneId'] = zone_id
    r_record = {
      "TTL" => "900",
      "Name" => format('%s.%s', m_config['params']['host_name'], m_config['params']['domain_name']),
      "Type" => "CNAME",
      "Weight" => m_config['params']['init_weight'],
      "SetIdentifier" => { "Ref": 'AWS::StackName' },
      "ResourceRecords" => [{ "Fn::GetAtt": [ m_config['params']['alb_name'], "DNSName" ] }]
    }
    json['Resources']['DNSEntry']['Properties']['RecordSets'] = [r_record]

    @stack_tpl['Resources'] = @stack_tpl['Resources'].deep_merge(json['Resources'])
  end

  def asg( m_config )
    json = load_module('asg')

    if m_config['params'].has_key?('user_data_script')
      user_data = load_script m_config['params']['user_data_script']
      launch_config = @stack_tpl['Resources'].select { |r_name, r_info| r_info["Type"] == "AWS::AutoScaling::LaunchConfiguration" }.first
      @stack_tpl['Resources'][launch_config[0]]['Properties']['UserData'] = {"Fn::Base64" => user_data}
    end

    @stack_tpl['Parameters'] = @stack_tpl['Parameters'].deep_merge(json['Parameters'])
  end

  def get_subnets( vpc_id, subnet_name )
    cache_key = format('subnets_%s_%s_%s', subnet_name, vpc_id, ENV['AWS_DEFAULT_REGION'])
    #@cache.del_key cache_key
    subnets = @cache.cached_json(cache_key) do
      filters = [{
        name: 'tag:Name',
        values: [subnet_name]
      },{
        name: 'vpc-id',
        values: [vpc_id]
      }]
      Log.debug('Subnet filters: %s' % filters.inspect)
      creds = Aws::SharedCredentials.new()
      ec2_client = Aws::EC2::Client.new(credentials: creds)
      ec2_client.describe_subnets(filters: filters).data.to_h.to_json
    end
  end

  def security_group( m_config )
    sg_json = load_module('security_group')
    
    sg_json['SG']['Properties']['GroupDescription'] = m_config['description']

    ingress_rules = []
    m_config['params']['allow'].each do |allow|
      if allow.has_key? 'subnet'
        ## do subnet lookup
        subnets = get_subnets( get_param( 'VpcId' ), allow['subnet'])

        subnets['subnets'].each do |subnet|
          ingress_rules.push({ 
            "CidrIp" => subnet['cidr_block'],
            "ToPort" => allow['to'],
            "FromPort" => allow['from'],
            "IpProtocol" => allow['protocol'] 
          })
        end

      else
        ingress_rules.push({ 
          "CidrIp" => allow['cidr'],
          "ToPort" => allow['to'],
          "FromPort" => allow['from'],
          "IpProtocol" => allow['protocol'] 
        })
      end

    end

    sg_json['SG']['Properties']['SecurityGroupIngress'] = ingress_rules
    @stack_tpl['Resources'][m_config['name']] = sg_json['SG']
  end

  def vpc_client( m_config )
    json = load_module('vpc_client')
    creds = Aws::SharedCredentials.new()

    ## VpcId
    cache_key = format('vpcs_%s', ENV['AWS_DEFAULT_REGION'])
    vpcs = @cache.cached_json(cache_key) do
      filters = [{
        name: 'tag:Name',
        values: [m_config['params']['vpc']['name']]
      },{
        name: 'tag:Version',
        values: [m_config['params']['vpc']['version']]
      }]
      ec2_client = Aws::EC2::Client.new(credentials: creds)
      ec2_client.describe_vpcs(filters: filters).data.to_h.to_json
    end

    if vpcs['vpcs'].size == 0
      raise Exception.new('Unable to locate vpc')
    end

    vpc_id = vpcs['vpcs'].first['vpc_id']
    @stack_tpl['Parameters']['VpcId'] = json['Parameters']['VpcId']

    set_param( 'VpcId', vpc_id )
    
    ## Allow all traffic from security subnets
    ## Allow only ssh from bastion subnets

    m_config['params']['require_subnets'].each do |subnet_name|
      cache_key = format('subnets_%s_%s_%s', subnet_name, vpc_id, ENV['AWS_DEFAULT_REGION'])
      #@cache.del_key cache_key
      subnets = @cache.cached_json(cache_key) do
        filters = [{
          name: 'tag:Name',
          values: [subnet_name]
        },{
          name: 'vpc-id',
          values: [vpc_id]
        }]
        Log.debug('Subnet filters: %s' % filters.inspect)
        ec2_client = Aws::EC2::Client.new(credentials: creds)
        ec2_client.describe_subnets(filters: filters).data.to_h.to_json
      end

      zone_param_tpl = deep_copy json['Parameters']['Zones']
      subnet_param_tpl = deep_copy json['Parameters']['Subnets']

      @stack_tpl['Parameters'][format('%sZones', subnet_name)] = zone_param_tpl
      @stack_tpl['Parameters'][format('%sSubnets', subnet_name)] = subnet_param_tpl

      set_param(format('%sZones', subnet_name), subnets['subnets'].map{|s| s['availability_zone'] })
      set_param(format('%sSubnets', subnet_name), subnets['subnets'].map{|s| s['subnet_id'] })
    end

    ## Clear out the placeholder artifacts from the template.
    json['Parameters'].delete 'Zones'
    json['Parameters'].delete 'Subnets'
    json['Parameters'].delete 'BastionCidr'
  end

  def network( m_config )
    cache_key = 'azs_%s' % ENV['AWS_DEFAULT_REGION']

    ## bastion route table requires igw
    ## all others should use a nat

    azs = @cache.cached_json(cache_key) do
      creds = Aws::SharedCredentials.new()
      ec2_client = Aws::EC2::Client.new(credentials: creds)
      ec2_client.describe_availability_zones().data.to_h.to_json
    end

    net = NetAddr::CIDR.create(m_config['params']['cidr'])
    blocks = net.subnet(:Bits => 24)

    @stack_tpl['Resources']['VPC']['Properties']['CidrBlock'] = m_config['params']['cidr']

    i = 0
    subnet_block_i = 0
    m_config['params']['subnets'].each do |m_subnet|
      block_size = if m_subnet['size'] == 'large'
        4
      elsif m_subnet['size'] == 'medium'
        2
      else
        1
      end

      # Log.debug("subnet_block_i: %i\tblock_size: %i" % [subnet_block_i, block_size])

      az_list = if m_subnet['cross_zone'] == false
        [azs['availability_zones'].first]
      else
        azs['availability_zones']
      end

      # pp m_subnet

      az_list.each do |az|
        subnet = deep_copy @stack_tpl['Resources']['Subnet']

        prefix = if m_subnet['public'] == true
          'Public'
        else
          'Private'
        end

        #Log.debug('prefix: %s' % prefix)

        subnet_rta_name = format('%sSubnetRTA%i', prefix, i)
        subnet_rta = deep_copy @stack_tpl['Resources'][format('%sSubnetRouteTableAssociation', prefix)]

        subnet['Properties']['Tags'].push({
          'Key' => 'Name',
          'Value' => m_subnet['name']
        })

        subnet_cidr = NetAddr::merge(blocks[subnet_block_i,block_size]).first
        subnet['Properties']['CidrBlock'] = subnet_cidr
        subnet['Properties']['AvailabilityZone'] = az['zone_name']

        subnet_rta['Properties']['SubnetId'] = {"Ref" => format('Subnet%i', i)}

        if m_subnet['use_nat'] == true
          subnet['Properties']['MapPublicIpOnLaunch'] = true
          @stack_tpl['Resources']['NAT']['Properties']['SubnetId'] = {'Ref' => format('Subnet%i', i)}
        end

        @stack_tpl['Resources'][format('Subnet%i', i)] = subnet
        @stack_tpl['Resources'][subnet_rta_name] = subnet_rta

        i+=1
        subnet_block_i += block_size
      end
    end

    @stack_tpl['Resources'].delete 'Subnet'
    @stack_tpl['Resources'].delete 'PublicSubnetRouteTableAssociation'
    @stack_tpl['Resources'].delete 'PrivateSubnetRouteTableAssociation'

    @stack_tpl['Resources']['VPC']['Properties']['Tags'].push({
      'Key' => 'Name',
      'Value' => m_config['params']['name']
    })

    @stack_tpl['Resources']['VPC']['Properties']['Tags'].push({
      'Key' => 'Version',
      'Value' => {"Ref": "StackVersion"}
    })
  end


end
