---
layout: post
title:  "Creating dynamic subnets and modular design."
date:   Tue Aug  22 11:10:33 PDT 2017
categories: cloudformation
---

<h1>Overview</h1>

<p>
In this episode we'll tackle enterprise network layouts.  This work is a reflection of the layouts that I've seen at various enterprise 
companies over the years.  The high level idea here is to use subnets to isolate network traffic by segmenting networks into network
<b>contexts</b>.  Each context is thought of as a layer which can only talk to other specific layers. 
</p>

<p>
This gives us some advantages:
</p>

<ul>
  <li>Granular, specific control of network flows from one subnet ( or group of subnets ) to another subnet ( or group of subnets ) through the use of NACL's and SecurityGroups ( SGs ).</li>
  <li>With this granular control we can add network flow logs with something like Splunk to further analyze the flow of data.</li>
  <li>Isolation at the network level prevents malicious actors from accessing more of our network.</li>
  <li>Happy security teams!</li>
</ul>


<h3>Contexts</h3>

<p>
Here are the contexts, or layers, that are in play.  The intent here is that each context will be represented as at least one subnet within the VPC.  
Most of the contexts will need to expand across all zones because we want to use everything available to us, however, something like the bastion context
doesn't need cross zone functionality, at least not in this example.
</p>

<ul>
  <li>PublicLoadBalancer: ALB's and ELB's live here.</li>
  <li>Application: EC2 instances that run application workloads.</li>
  <li>Cache: EC2 instances or hosted services for memcache/redis and the like</li>
  <li>Data: Same as cache, but specifically called out as reserved for data services like mysql or pg.</li>
  <li>Security: Any type of security related software as required by our security teams.</li>
  <li>Bastion: Entry point into the network; this is also where we put the NAT</li>
  <li>Monitoring: Splunk, ELKS, or whatever you use for monitoring things</li>
</ul>

<p>
In some cases people are tempted to try to make this stuff by hand stuffing all of the subnet Id's into a yaml file somewhere.  The math on this is
difficult given the complexity here, which is why I've done so much work around programming and automation in this space.
</p>

<p>
us-east-1 has 6 zones, so if we state that we want 6 contexts in 6 zones that 36 subnet id's for one environment alone, not to mention the CIDR block
management and subnet associations involved in this.  This would be an absolute nightmare to try to pull off by hand.  In fact, any manual work
here would probably end up being largely painful here.
</p>

<p>
And that's why we automate!
</p>

<h1>Modular design</h1>

<p>
During this body of work I realized that I needed to expand the modular design of how I'm compiling things.
</p>

<h1>Network</h1>

<p>
<a href="https://github.com/krogebry/devops/blob/master/aws/cloudformation/profiles/network-dev.yml">Here</a> is the network yaml for the dev environment.
This is showing how I intend to build out the dev network.  The really interesting parts here are how each subnet has a <i>size</i> value which determines
how many IP's are in a subnet's CIDR block.
</p>

<ul>
  <li>small: 1 bit ( /24 )</li>
  <li>medium: 2 bits ( /23 )</li>
  <li>large: 4 bits ( /22 )</li>
</ul>

<p>
This allows me to have t-shirt sizes for my subnets which is easier to conceptualize than trying to do subnet cidr math in my head.
</p>

<h1>Stacks</h1>

<p>
I wanted to have a real, working application running inside the network I've created that could mirror an actual application.
To this end, I ended up breaking this into three stacks:
</p>

<ul>
	<li>network</li>
	<li>bastion</li>
	<li>workout tracker</li>
</ul>

<p>
Each stack is described in more detail below.  In each section is a link to the yaml file that was used as the profile,
the stack template json, and the params json.  These are the working stacks that actually work do exactly what I'm describing.
</p>

{% highlight bash %}
aws cloudformation get-template --stack-name network-dev-0-3-0|jq '.TemplateBody' > template.json
aws cloudformation describe-stacks --stack-name network-dev-0-3-0|jq '.Stacks[0].Parameters' > params.json
{% endhighlight %}

<h2>Network</h2>

<ul>
  <li><a href="https://github.com/krogebry/devops/blob/master/aws/cloudformation/profiles/network-dev.yml">YAML</a></li>
  <li><a href="/devops//code/2017-08-22/network/template.json">Template</a></li>
  <li><a href="/devops//code/2017-08-22/network/params.json">Params</a></li>
</ul>

<p>
A context with <b>public</b> will cause the subnet to be associated with the default public route table.  The public route table
has a default route pointing to the IGW.  However, if it's not public, then the assumption is that it's private and therefor
requires routing out of the vpc via a NAT.
</p>

<p>
In this design the default route for a private network will always route out of the NAT gateway that is hosted in the bastion
subnet.  The <b>cross_zone</b> variable allows me to have only one subnet for a given subnet.  If we changed cross_zone for
bastion, then we'd end up with 6 subnets, but only one NAT and a bit of confusion.  I'd have to put more work into creating
dynamic NAT's with associated EIP allocations.  I punted on the dynamic NAT generation here because I don't currently
need this functionality.  A single NAT is fine for a dev environment.  Also, not everything needs to be automated all
at once, we can do this part in a later iteration.
</p>

<h2>Bastion</h2>

<ul>
  <li><a href="https://github.com/krogebry/devops/blob/master/aws/cloudformation/profiles/bastion-dev.yml">YAML</a></li>
  <li><a href="/devops//code/2017-08-22/bastion/template.json">Template</a></li>
  <li><a href="/devops//code/2017-08-22/bastion/params.json">Params</a></li>
</ul>

<p>
The bastion host is fairly simple in that it's just an ASG where all EC2 instances will have a public IP.
I decided to punt on the work which binds the external IP to a DNS entry dynamically because I'm going to cover that
in a different post and probably use lambda.
</p>

<p>
I use the ssh proxy command trick to make jumping into an instance easier.
</p>

{% highlight ssh %}
StrictHostKeyChecking no

Host bastion-dev.krogebry.com
  User ec2-user
  IdentityFile ~/.ssh/keys/devops-1.pem

Host 10.1.*.*
  User ec2-user
  IdentityFile ~/.ssh/keys/devops-1.pem
  ProxyCommand ssh bastion-dev.krogebry.com nc %h %p
{% endhighlight %}

<h2>Workout tracker</h2>

<ul>
  <li><a href="https://github.com/krogebry/devops/blob/master/aws/cloudformation/profiles/workout-tracker-dev.yml">YAML</a></li>
  <li><a href="/devops//code/2017-08-22/workout-tracker/template.json">Template</a></li>
  <li><a href="/devops//code/2017-08-22/workout-tracker/params.json">Params</a></li>
</ul>

<p>
Finally we have the actual application itself which is hosted in ECS and fronted by an ALB.
The best part about this is that the SG is specifically locked down to only allowing the ECS port range from the load balancer subnets.
This happens because of the security_group module.
</p>

{% highlight yaml %}
  - name: "EC2ClusterInstances"
    type: "security_group"
    description: "EC2 cluster instances."
    params:
      allow:
        - subnet: Bastion
          to: 22
          from: 22
          protocol: tcp
        - subnet: PublicLoadBalancer
          to: 65535
          from: 32768
          protocol: tcp
{% endhighlight %}

<p>
In this case a single security group will be created which will have 7 total rules.  6 rules are created from expanding the PublicLoadBalancer subnets, and 1 group
which is expanded from the Bastion subnet.  This is done by using a helper function which gets our list of subnets:
</p>

{% highlight ruby %}
  def get_subnets( vpc_id, subnet_name )
    cache_key = format('subnets_%s_%s_%s', subnet_name, vpc_id, ENV['AWS_DEFAULT_REGION'])
    subnets = @cache.cached_json(cache_key) do
      filters = [{
        name: 'tag:Name',
        values: [subnet_name]
      },{
        name: 'vpc-id',
        values: [vpc_id]
      }]
      Log.debug('Subnet filters: %s' % filters.inspect)
      creds = Aws::SharedCredentials.new()
      ec2_client = Aws::EC2::Client.new(credentials: creds)
      ec2_client.describe_subnets(filters: filters).data.to_h.to_json
    end
  end
{% endhighlight %}

<p>
This is how we can use the tags to find things in the AWS ecosystem and generally make our lives a little easier.
This is also using a file based caching mechanism which makes things easier for development.  I'm not hitting the API's
every single time for the same information that isn't changing.  This is a handy trick when dealing with clients
who are constantly on the edge of their API rate limits ( which happens often when splunk and other SaaS's are in play ).
</p>

<a href="/devops/code/2017-08-22/workout-tracker/security_group.json">Example</a>

<p>
The isolation here keeps things from bleeding over into different networks, but more importantly this allows me to express complicated
network rules for the thing I'm protecting.  At the same time I'm keeping the protection bundled with the actual objects I'm protecting.
Along with this I'm also expressing complicated network rules while not burning up large groups of security group allocations.  In some
cases people are tempted to create a unique SG for each rule, however, AWS allows us to express many rules in a single group.
</p>

<p>
The alternative model here is to split the SG's out into their own unique entities separate from the environment or stacks.  I think this
is wrong because of the blast radius argument.  If someone changes a security group in that model, then you run the risk of exposing anything
else that's also connected to that SG.  In contrast, this model specifically isolates the potential danger down the stack of resources, thus
hampering the blast radius of damage that could occur.  In this way I'm following the intent of the subnet layering by providing an additional
construct of abstraction and isolation.
</p>

