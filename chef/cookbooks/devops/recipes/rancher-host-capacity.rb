

docker_image node['rancher']['agent']['image'] do
  tag node['rancher']['agent']['version']
  action :pull
end

docker_container 'rancher-agent' do
  image node['rancher']['agent']['image']
  tag node['rancher']['agent']['version']
  command "http://#{server_host}:#{node['rancher']['server']['port']}"
  volume '/var/run/docker.sock:/var/run/docker.sock'
  container_name 'rancher-agent-init'
  init_type false
  detach false
  not_if 'docker inspect rancher-agent'
end

