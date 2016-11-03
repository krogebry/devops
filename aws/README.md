# Overview

AWS things.

# Launch

Launch the stacks.


## Create the infrastructure

```bash
source ~/.aws/TARGET
rake cf:launch['inf-use1, Inf, 0.2.0']
```

## Update profiles to reflect Inf version.

```bash
vi cloudformation/profiles/chef-server-use1.yml
vi cloudformation/profiles/gocd-use1.yml
```

Update *S3BucketName - Version* to the version of the Inf stack.

```bash
rake cf:launch['chef-server-use1, Chef-Server, 0.2.0']
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
