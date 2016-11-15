##
# Rancher management.
##
chef_gem 'json'
chef_gem 'aws-sdk'

require 'json'
require 'aws-sdk'

region = `curl -s 169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/.$//'`.chomp

#creds = Aws::SharedCredentials.new()
creds = Aws::InstanceProfileCredentials.new()
s3_client = Aws::S3::Client.new(region: region, credentials: creds, signature_version: 'v4')
kms_client = Aws::KMS::Client.new(region: region)

inf_version = "0.6.10"

kms_key_alias= 'alias/devops'
#kms_key_alias= 'alias/snacks_dev'

aliases = kms_client.list_aliases.aliases

key = aliases.find { |alias_struct| alias_struct.alias_name == kms_key_alias }
key_id = key.target_key_id
s3_encryption_client = Aws::S3::Encryption::Client.new(
  client: s3_client,
  kms_key_id: key_id,
  kms_client: kms_client,
)

env_name = "management"
target = "rancher-mgt"

r = s3_encryption_client.get_object(bucket: format('dev-central-%s', inf_version), key: format('%s/%s', env_name, target))

#r = s3_client.get_object(bucket: format('dev-central-%s', inf_version), key: 'rancher/management/secrets.json')
secrets = JSON::parse(r.body.read)
pp secrets

## Env
#db_name = node['devops']['rancher']['db']['name']
#db_port = node['devops']['rancher']['db']['port']
#db_type = node['devops']['rancher']['db']['type']
#db_hostname = node['devops']['rancher']['db']['hostname']

#edb = data_bag_item('rancher', 'management', IO.read('/etc/chef/edb_key'))

## DataBag
#db_username = edb['devops']['rancher']['db']['username']
#db_password = edb['devops']['rancher']['db']['password']

#env = []
#env.push(format("CATTLE_DB_CATTLE_DATABASE=%s", db_type ))

#env.push(format("CATTLE_DB_CATTLE_MYSQL_HOST=%s", db_hostname ))
#env.push(format("CATTLE_DB_CATTLE_MYSQL_NAME=%s", db_name ))
#env.push(format("CATTLE_DB_CATTLE_MYSQL_PORT=%i", db_port ))

#env.push(format("CATTLE_DB_CATTLE_USERNAME=%s", db_username ))
#env.push(format("CATTLE_DB_CATTLE_PASSWORD=%s", db_password ))

#docker_container 'rancher-management-service' do
	#env envs
  #repo 'rancher/server'
  #port '8080:8080'
#end

