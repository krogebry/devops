##
# Kibana overrides.
##
#gem_package 'aws-sdk'
#execute "install gem"
  #command "/opt/chef/embedded/bin/gem install aws-sdk"
#end

#ruby_block "require gem" do
  #code <<EOF
    #require 'aws-sdk'
#EOF
#end

## Disable the default site.
#node.default['nginx']['default_site_enabled'] = false

#elb_client = Aws::ElasticLoadBalancing::Client.new()

#elbs = elb_client.describe_load_balancers().data.to_h.to_json
#elb_names = []
#elbs['load_balancer_descriptions'].each do |elb|
	#elb_names.push( elb['load_balancer_name'] )
#end

#v = { 'tags' => {
	#'Name' => 'ESCluster',
	#'Role' => 'External',
	#'Version' => node['devops']['es_cluster_version']
#}}

#elb_client.describe_tags({ load_balancer_names: elb_names }).data.to_h.to_json
#elb_target = elb_tags['tag_descriptions'].select{|elb| elb['tags'].select{|t| v['tags'].select{|k,v| t['key'] == k && t['value'] == v}.size == 1 }.compact.size == v['tags'].size }.first
#elb_target = elbs['load_balancer_descriptions'].select{|elb| elb['load_balancer_name'] == elb_target['load_balancer_name'] }.first['dns_name']

## Set ESCluster DNS hostname and port.
#node.default['kibana']['elasticsearch']['port'] = 80
#node.default['kibana']['elasticsearch']['hosts'] = [elb_target]
