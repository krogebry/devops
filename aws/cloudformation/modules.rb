
class ModulesProc
  @cache
  @config
  @params
  @s3_client
  @ec2_client
  @elb_client
  @sns_client

  @stack_tpl

  def initialize(yaml, stack_tpl)
    @config = yaml
    @stack_tpl = stack_tpl

    @cache = DevOps::Cache.new
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
    @stack_tpl
  end

  def deep_copy( hash )
    Marshal.load(Marshal.dump(hash))
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

end
