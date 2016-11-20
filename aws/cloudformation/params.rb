##
# Params processor
##

class ParamsProc
  @config
  @params
  @s3_client
  @ec2_client
  @elb_client
  @sns_client

  FS_CACHE_DIR = File::join( '/', 'tmp', 'devops', 'cache' )

  def initialize( yaml )
    creds = Aws::SharedCredentials.new()
    @s3_client = Aws::S3::Client.new(region: yaml['region'], credentials: creds)
    @ec2_client = Aws::EC2::Client.new(region: yaml['region'], credentials: creds)
    @elb_client = Aws::ElasticLoadBalancing::Client.new(region: yaml['region'], credentials: creds)
    @sns_client = Aws::SNS::Client.new(region: yaml['region'], credentials: creds)
    @config = yaml
    @params = yaml['params']

    init_cache
  end

  def self.flush()
    system(format('rm -rf %s/*', FS_CACHE_DIR))
  end

  def init_cache()
    FileUtils::mkdir_p FS_CACHE_DIR
  end

  def get_filters( a )
    ro = []
    a.each do |k,v|
      Log.debug(format('%s - %s', k, v))
      if v.match( /^ENV:/ )
        Log.debug(format('Doing sub on: %s', k))
        (env, var_name) = v.split( ':' )
        v = ENV[var_name]
      end

      ro.push({
        name: format('tag:%s', k),
        values: [v]
      })
    end
    ro
  end

  def compile()
    ## Find any deps.
    @params.each do |k,v|
      Log.debug(format('%s - %s', k,v ))

      if(v.class == Hash && v.has_key?( 'type' ))
        begin
          v = self.send( v['type'], v )
        rescue NoMethodError => e
          Log.fatal(format('Unknown method error: %s - %s', v['type'], e))
          pp e.backtrace
          exit
        rescue => e
          Log.fatal(format('Unknown error: %s', e ))
          pp e.backtrace
          exit
        end

      else
        if(v.match(/^ENV:.*/))
          (env, var) = v.split(/:/)
          @params[k] = { 'value' => ENV[var] }
        end

      end
    end
  end

  def cached_json( key )
    data = []
    fs_cache_file = File.join( '/', 'tmp', 'cache', key )
    FileUtils.mkdir_p(File.dirname( fs_cache_file )) unless File.exists?(File.dirname( fs_cache_file ))
    if(File.exists?( fs_cache_file ))
      data = File.read( fs_cache_file )
    else
      Log.debug('Getting from source')
      data = yield
      File.open( fs_cache_file, 'w' ) do |f|
        f.puts data
      end
    end
    return JSON::parse( data )
  end

  def vpc_cidr( v )
    cache_key = format('vpcs-%s-%s', @config['region'], ENV['AWS_PROFILE'])
    vpcs = cached_json( cache_key ) do 
      @ec2_client.describe_vpcs({ filters: get_filters( v['tags'] )}).data.to_h.to_json
    end

    if(vpcs['vpcs'].size == 0)
      Log.fatal(format('Unable to find VPC!'))
      exit
    end

    v['value'] = vpcs['vpcs'].first['cidr_block']
  end

  def ami( v )
    cache_key = format('images-%s-%s-%s', @config['region'], ENV['AWS_PROFILE'], Digest::SHA1.hexdigest( v['tags'].to_s ))
    Log.debug(cache_key)
    objects = cached_json( cache_key ) do 
      @ec2_client.describe_images({ filters: get_filters( v['tags'] )}).data.to_h.to_json
    end

    if(objects['images'].size == 0)
      Log.fatal(format('Unable to find image!'))
      exit
    end

    v['value'] = objects['images'].first['image_id']
    v
  end

  def get_elbs()
    cache_key = format('elb-%s-%s', @config['region'], ENV['AWS_PROFILE'])
    cached_json( cache_key ) do
      @elb_client.describe_load_balancers().data.to_h.to_json
    end
  end

  def get_elb_tags( elb_names )
    cache_key = format('elb-%s-%s-tags', @config['region'], ENV['AWS_PROFILE'])
    cached_json( cache_key ) do
      @elb_client.describe_tags({ load_balancer_names: elb_names }).data.to_h.to_json
    end
  end

  def get_elbs_with_tags()
    elbs = get_elbs
    elb_names = []
    elbs['load_balancer_descriptions'].each do |elb|
      elb_names.push( elb['load_balancer_name'] )
    end
    [elbs, get_elb_tags( elb_names )]
  end

  def elb_dns( v )
    (elbs, elb_tags) = get_elbs_with_tags()

    tags = {}
    v['tags'].each do |k,v|
      if v.match( /^ENV:/ )
        Log.debug(format('Doing sub on: %s', k))
        (env, var_name) = v.split( ':' )
        v = ENV[var_name]
      end
      tags[k] = v
    end
    pp tags

    ## Find the number of targets that have the same number of match tags as were past from the params yaml data.
    elb_target = elb_tags['tag_descriptions'].select{|elb| elb['tags'].select{|t| r = tags.select{|k,v| t['key'] == k && t['value'] == v }.size == 1 }.compact.size == tags.size }.first

    if(elb_target == nil)
      Log.fatal(format('Unable to find ELB DNS!'))
      exit
    end

    v['value'] = elbs['load_balancer_descriptions'].select{|elb| elb['load_balancer_name'] == elb_target['load_balancer_name'] }.first['dns_name']
    v
  end

  def vpc( v )
    cache_key = format('vpcs-%s-%s', @config['region'], ENV['AWS_PROFILE'])
    vpcs = cached_json( cache_key ) do 
      @ec2_client.describe_vpcs({ filters: get_filters( v['tags'] )}).data.to_h.to_json
    end
    v['value'] = vpcs['vpcs'].first['vpc_id']
    v
  end

  def password( v )
    v['value'] = SecureRandom.hex
    v
  end

  def s3_bucket( v )
    filters = get_filters( v['tags'] )

    bucket_name = format("%s-%s", filters.select{|f| f[:name] == 'tag:Name' }.first[:values][0], filters.select{|f| f[:name] == 'tag:Version' }.first[:values][0])
    Log.debug(format('Bucket: %s', bucket_name))

    cache_key = format('s3_buckets-%s-%s', @config['region'], ENV['AWS_PROFILE'])

    buckets = cached_json( cache_key ) do
      @s3_client.list_buckets().data.to_h.to_json
    end
    bucket = buckets['buckets'].select{|b| b['name'] == bucket_name }.first

    ## Fail if we can't find the bucket.
    if bucket == nil
      Log.fatal(format('Unable to find bucket: %s', bucket_name))
      exit
    end

    v['value'] = bucket_name
    v
  end

  def sns_topic_arn( v )
    cache_key = format('sns_topics-%s-%s', @config['region'], ENV['AWS_PROFILE'])
    sns_topics = cached_json( cache_key ) do
      @sns_client.list_topics().data.to_h.to_json
    end
    Log.debug(format('Looking for: %s', v['tags']['Name']))

    topic = sns_topics['topics'].select{|t| t['topic_arn'].match( /#{v['tags']['Name']}/ )}.first
    if topic == nil
      Log.fatal(format('Unable to find SNS topic: %s' % v['tags']['Name']))
      exit
    end

    v['value'] = topic['topic_arn']
    v
  end

  def find_subnet( tag )
    cache_key = format('subnets-%s-%s-%s', @config['region'], ENV['AWS_PROFILE'], Digest::SHA1.hexdigest( tag.to_s ))
    cached_json( cache_key ) do
      @ec2_client.describe_subnets({ filters: get_filters( tag )}).data.to_h.to_json
    end
  end

  def zones( v )
    zones = []
    v['tags'].each do |tag|
      subnet = find_subnet( tag )
      zones.push( subnet['subnets'].first['availability_zone'] )
    end
    v['value'] = zones.join(',')
    v
  end

  def subnets( v )
    subnets = []
    v['tags'].each do |tag|
      subnet = find_subnet( tag )
      subnets.push( subnet['subnets'].first['subnet_id'] )
    end
    v['value'] = subnets.join(',')
    v
  end

end
