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

## Create the infrastructure

```bash
source ~/.aws/TARGET
rake cf:flush_cache
rake cf:launch['inf-use1, Inf, 0.2.0']
```

## Update profiles to reflect Inf version

```bash
vi cloudformation/profiles/chef-server-use1.yml
vi cloudformation/profiles/gocd-use1.yml
```

Update *S3BucketName - Version* to the version of the Inf stack.

```bash
rake cf:launch['chef-server-use1, Chef-Server, 0.2.0']
```

## Bootstrap chef server

First, update the knife config

```bash
rake cf:mk_chef_config['0.4.0, us-east-1']
unlink knife.rb
ln -s knife-0.4.0.rb knife.rb
knife node list
```

Now bootstrap the chef server.

```bash
cd ../chef
rake chef:bootstrap
```

## Now create the GoCD service

```bash
rake cf:launch['gocd-use1, GoCD, 0.2.0']
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
