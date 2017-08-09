
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

    attach = m_config['params'].has_key?('attach') ? m_config['params']['attach'] : 'all'
    Log.debug('attach: %s' % attach)

    if attach == 'all'
      asgs = @stack_tpl['Resources'].select{|k,v| v['Type'] == "AWS::AutoScaling::AutoScalingGroup"}
      asgs.each do |asg_name, asg_cfg|
        new_json = deep_copy(json)
        policies = new_json['Resources'].select{|k,v| v['Type'] == "AWS::AutoScaling::ScalingPolicy"}
        policies.each do |policy_name, policy_config|
          policy_config['Properties']['AutoScalingGroupName'] = { 'Ref' => asg_name }
        end
        @stack_tpl['Resources'] = @stack_tpl['Resources'].deep_merge(new_json['Resources'])
      end
    end
  end

end
