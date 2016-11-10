##
# Rancher management.
##

## Env
db_name = node['devops']['rancher']['db']['name']
db_port = node['devops']['rancher']['db']['port']
db_type = node['devops']['rancher']['db']['type']
db_hostname = node['devops']['rancher']['db']['hostname']

#edb = data_bag_item('rancher', 'management', IO.read('/etc/chef/edb_key'))

## DataBag
#db_username = edb['devops']['rancher']['db']['username']
#db_password = edb['devops']['rancher']['db']['password']

env = []
env.push(format("CATTLE_DB_CATTLE_DATABASE=%s", db_type ))

env.push(format("CATTLE_DB_CATTLE_MYSQL_HOST=%s", db_hostname ))
env.push(format("CATTLE_DB_CATTLE_MYSQL_NAME=%s", db_name ))
env.push(format("CATTLE_DB_CATTLE_MYSQL_PORT=%i", db_port ))

env.push(format("CATTLE_DB_CATTLE_USERNAME=%s", db_username ))
env.push(format("CATTLE_DB_CATTLE_PASSWORD=%s", db_password ))

docker_container 'rancher-management-service' do
	env envs
  repo 'rancher/server'
  port '8080:8080'
end

