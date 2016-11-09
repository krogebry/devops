# Overview

AWS things.

# TODO list

* [krogebry - Sun Nov  6 10:42:44 CST 2016]: linking/unlinking of knife.rb
* [krogebry - Sun Nov  6 15:25:42 CST 2016]: 
  * Create logstash client things.
  * Log standard log files.
  * Log chef things.
  * Grafana service, with nodes reporting via collectd.
  * Sensu stack for alarming.


# Launch

Launch the stacks.

*~/.aws/PROFILE*

```bash
export AWS_PROFILE="PROFILE"
export INF_VERSION="0.5.0" 
export CHEF_VERSION="0.5.4" 
export AWS_REGION="us-east-2"

source ~/.aws/PROFILE
```

## Create the infrastructure

```bash
rake cf:flush_cache
rake cf:launch['inf, Inf, 0.6.2']
```

## Create the chef server

```bash
rake cf:launch['chef-server, ChefServer, 0.6.2']
```

## Bootstrap chef server

First, update the knife config

```bash
rake cf:mk_chef_config['0.5.4, 0.5.0, us-east-2']
unlink ~/.chef/knife.rb
ln -s ~/.chef/knife-0.4.0.rb ~/.chef/knife.rb
knife node list
```

Now bootstrap the chef server.

```bash
cd ../chef
rake chef:bootstrap
```

## Now create the services

```bash
rake cf:launch['gocd, GoCD, 0.6.2']
rake cf:launch['gocd-agents, GoCDAgents, 0.6.2']
rake cf:launch['es-cluster, ESCluster, 0.6.2']
rake cf:launch['kibana, Kibana, 0.6.2']
rake cf:launch['vault, Vault, 0.6.2']
rake cf:launch['sensu, Sensu, 0.6.2']
```

## Security

Ideally we'd want to lock down the assets that are created with this system.

## TODO

* Button down the IAM security.
* Make Inf version something we can pass or find.
* Add yamllint to package install


```json
Policies": [{
  "PolicyName" : "GoCDWebSocketPolicy",
  "PolicyType" : "ProxyProtocolPolicyType",
  "Attributes" : [{ "Name" : "ProxyProtocol", "Value" : "true" }]
}]
```
