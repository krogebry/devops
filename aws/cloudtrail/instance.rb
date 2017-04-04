

class EC2Instance
  @data
  @cache

  @ec2_client

  attr_accessor :data, :cache, :ec2_client
  def initialize(instance)
    @data = instance
    @cache = DevOps::Cache.new()

    creds = Aws::SharedCredentials.new()
    @ec2_client = Aws::EC2::Client.new(region: 'us-west-2', credentials: creds)
  end

  def rate
    rating = 0

    return 0 if get_state != 'running'

    rating += self.rate_age
    rating += self.rate_exposure
    rating += self.rate_networking

    #Log.debug('Rating for %s: %s' % [@data['instance_id'], rating])
    rating
  end

  def get_state
    @data['state']['name']
  end

  def rate_age
    now = Time.new.to_f
    #Log.debug('Rating age')
    launch_time = Time.parse(@data['launch_time'])
    #Log.debug('LaunchTime: %s' % launch_time)
    age = now - launch_time.to_f
    num_days = (age/86400)
    #Log.debug('Age: %s / %s' % [age, num_days])
    (num_days > 30 ? 1 : 0)
  end

  def rate_exposure
    exposure_rating = 0
    #Log.debug('Rating exposure')
    #pp @data['security_groups']
    @data['security_groups'].each do |sg|
      sg = get_security_group(sg['group_id'])
      return 0 if sg == false
      sg_rating = 0
      sg['security_groups'].each do |sg|
        sg['ip_permissions'].each do |sg_rule|
          sg_rating += rate_ip_rule(sg_rule)
          #Log.debug('SGRating: %s' % sg_rating)
        end
      end
      #Log.debug('SGRating: %s' % sg_rating)
      exposure_rating += sg_rating
    end
    exposure_rating
  end

  def rate_ip_rule(rule)
    #Log.debug('Rating rule' % rule)
    #pp rule
    return 1 if rule['ip_protocol'] == '-1'

    return 1 if rule['ip_protocol'] == 'tcp' and
        rule['from_port'] == 22 and
        rule['to_port'] == 22 and
        rule['ip_ranges'].select{|range| range['cidr_ip'] == '0.0.0.0/0'}.compact.size > 0

    return 1 if rule['ip_ranges'].select{|range| range['cidr_ip'] == '0.0.0.0/0'}.compact.size > 0

    return 0
  end

  def rate_networking
    networking_rating = 0
    return 0 if @data['network_interfaces'].size == 0
    @data['network_interfaces'].each do |ni|
      networking_rating += 10 if ni.has_key?('association') and ni['association']['public_ip'] != ""
    end
    networking_rating
  end

  def get_security_group(sg_id)
    cache_key = 'ec2_sg_%s' % sg_id
    @cache.cached_json(cache_key) do
      begin
        @ec2_client.describe_security_groups(group_ids: [sg_id]).data.to_h.to_json
      rescue Aws::EC2::Errors::InvalidGroupNotFound
        return false
      end
    end
  end
end

