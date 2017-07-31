---
layout: post
title:  "The NetworkDoctor"
date:   2017-07-30 14:28:48 -0700
categories: cloudtrail
---

<a href="https://github.com/krogebry/tattletrail">Code</a>

<p>
The idea with the netdoc was to create a way to check a few important aspects regarding how a vpc and subsequent subnets+route tables are setup.
</p>

<h1>User story</h1>

<p>
The need for this netdoc comes about from the following story.  To set this up, let's first define our subnet layout as such.
</p>

<ul>
	<li>VPC ( tag:Name,value:dev )</li>
	<li>Subnets:
	<ul>
	  <li>lbs: Public-facing load balancers.</li>
	  <li>routing: [E,A]LB's from <b>lbs</b> route to here and here only.  This is where we'll have our Nginx clusters doing URI routing.</li>
    <li>application_lbs: Application level [E,A]lbs</li>
    <li>applications: Applications, like EC2 instances for our ECS clusters.</li>
    <li>db_conn: Subnets for connecting RDS/DynamoDB</li>
    <li>cache: Subnets for our caching layer like memc or redis</li>
    <li>monitoring: Any time of monitoring or logging agents, like splunk forwarders or promethus rigs</li>
    <li>secdef: Security and defense applications.</li>
    <li>bastion: Jump boxes</li>
  </ul>
  </li>
</ul>

<p>
That's 9 subnets.  And yes, this is very close to a legit, no bullshit, enterprise layout that people often try to employ.  A reasonable person might suggest that you wouldn't need
this many subnets if you understand the nature of security groups.  I agree, however, it is often the case that logic and reason fail to compare to the power of the emotional
side which usually drives these decisions.  People often prefer to think they're safe, even if that means wildly over designed things.
</p>

<p>
It could also be argued that the over complexity of something like this leads to dangerous overtaxing of human based cognitive resources while we meat sacks attempt to debug
problems.  I guess that's why I started doing these projects; it's easier to run a script to tell me if something is wrong with your Rube Goldberg network layout.
</p>

<blockquote>
At one point we were working on a client which insisted that we automate everything.  And I do mean everything, from the key pair creation to the vpcs and everything else.
That's an ambitious goal for something that wasn't even close to limping its way out of the dev space.  At any rate, as you could imagine, managing the level of complexity
became an almost daily chore.  The people managing the system would often make changes to things in production to "just get things working" rather than submitting bugs
and following the procedures.

At one point we were troubleshooting a collection of problems with the dev account regarding traffic flow.  The problem that we faced most often was not being able to
tell at a glance if the subnets were able to talk to each other, and more specifically talk to their respective igw/nat chains.
</blockquote>

<p>
My thinking here is to be able to create something that can work with the TT system and help me grade a vpc/subnet rig based on it's ability to route and maybe a few
other factors.  This would be similar to the work down with awspec in that we're validating certain things about how aws resources are connected and used.  However
my thinking here is to create a rule in TT that can help us validate our assumptions.
</p>

<p>
It also might turn out that I end up breaking the netdoc off into its own little project that solves a very specific space.
</p>

<h1>Output</h1>

{% highlight ruby %}
krogebry@ubuntu-secure:~/dev/tattletrail$ rake netdoc:check_vpc['main']
D, [2017-07-30T14:57:30.083456 #7526] DEBUG -- : Creating NetworkDoctor for main
D, [2017-07-30T14:57:30.426432 #7526] DEBUG -- : Checking vpc: main
D, [2017-07-30T14:57:30.426509 #7526] DEBUG -- : CacheKey: vpc_us-east-1_Name_main
D, [2017-07-30T14:57:30.426657 #7526] DEBUG -- : Checking subnets
D, [2017-07-30T14:57:30.426697 #7526] DEBUG -- : CacheKey: vpc_subnets_vpc-21d67f46
D, [2017-07-30T14:57:30.426855 #7526] DEBUG -- : CacheKey: vpc_main_route_vpc-21d67f46
D, [2017-07-30T14:57:30.426971 #7526] DEBUG -- : CacheKey: vpc_subnet_route_subnet-5441157e
I, [2017-07-30T14:57:30.427150 #7526]  INFO -- : Subnet is routable
D, [2017-07-30T14:57:30.427213 #7526] DEBUG -- : CacheKey: vpc_subnet_route_subnet-816b3ad9
I, [2017-07-30T14:57:30.427443 #7526]  INFO -- : Subnet is routable
D, [2017-07-30T14:57:30.427501 #7526] DEBUG -- : CacheKey: vpc_subnet_route_subnet-629bad5f
I, [2017-07-30T14:57:30.427652 #7526]  INFO -- : Subnet is routable
D, [2017-07-30T14:57:30.427708 #7526] DEBUG -- : CacheKey: vpc_subnet_route_subnet-d2c5c1a4
I, [2017-07-30T14:57:30.427852 #7526]  INFO -- : Subnet is routable
{% endhighlight %}

