---
layout: post
title:  "Creating a simple application using the workout tracker."
date:   Tue Aug  8 15:10:33 PDT 2017
categories: cloudformation
---

<h1>Overview</h1>

<p>
The workout tracker program is a super dead simple little golang app that I've been working on over the past year or so.  It started out with a simple design as a way to help me keep track of my
workouts.  Easy enough, right?  Well, it turns out that the golang stuff was actually a bit of a flop.  I ended up solving the problem using google sheets and a little ruby code.
</p>

<p>
However, what I learned during this process is that my little go binary was super good at doing one very simple thing in that I could wrap up the bin into a docker container and use it
to do many POC things with AWS ECS.  In fact, I used this little fella extensively at a client to show how ECS deployments worked.
</p>

<p>
This was the workflow for demonstrating how we could do b/g deployments in ECS:
</p>

<ul>
  <li>Tune Makefile in project to reflect new version.  For example we might change "0.4.0" to "0.4.1".</li>
  <li><b>make build</b> will create a new binary which includes the new version string.</li>
  <li><b>make docker_image</b> will run docker build, which creates a new docker image with the new binary.</li>
  <li><b>make push</b> tags and pushes the docker image to ECR</li>
  <li>Then we had a little code that would create a new task def, then update the service with the new task def ID</li>
  <li>That would cause a deployment to happen in ECS for our service</li>
  <li>While all of this is going on we would be: <b>curl http://iambatman.client.com/version</b> every second which returns a json string with the version info.</li>
</ul>

<p>
The output would look something like this:
</p>

{% highlight bash %}
{ "version": "0.4.0" }
{ "version": "0.4.0" }
{ "version": "0.4.0" }
{ "version": "0.4.1" }
{ "version": "0.4.0" }
{ "version": "0.4.1" }
{ "version": "0.4.0" }
{ "version": "0.4.1" }
{ "version": "0.4.1" }
{ "version": "0.4.1" }
{ "version": "0.4.1" }
{ "version": "0.4.1" }
{ "version": "0.4.1" }
{% endhighlight %}

<p>
Both versions are running until the new version is completely switched over and all traffic has switched over to the new task.  ECS, like most systems like this, has free b/g deployments.
Pretty neat, huh?
</p>

<ul>
  <li><a href="https://github.com/krogebry/devops/">Devops project</a></li>
  <li><a href="https://github.com/krogebry/workout-tracker/">Workout tracker project</a></li>
</ul>

<p>
The intent with this post is to show how to create a dead simple container like this that can deploy a simple application that does a simple thing.  Simply.
</p>

<h1>Design</h1>

<p>
Let's start this process by laying out what we want to accomplish.  For now, I'm going to skip the DNS integration.  I might do that in a later post as to not confuse the simplicity of this project.
</p>

<ul>
  <li>Create a load balancer that can distribute traffic between application resources.</li>
  <li>Deploy compute resources for the cluster.</li>
  <li>Use ECS to deploy a containerized application on the cluster.</li>
  <li>Service should expose /version on the ALB DNS end point.</li>
</ul>

<p>
The devops project contains everything I need to launch a stack that does exactly this.  This is something that I've been putting together for years based on my work
with many different clients representing many different business models.  Here's how I launch my stack:
</p>

{% highlight bash %}
krogebry@ubuntu-secure:~/dev/devops/aws$ rake cf:launch['workout-tracker, 0.0.8, WorkoutTracker']
D, [2017-08-08T15:32:38.329970 #3245] DEBUG -- : FS(profile_file): cloudformation/profiles/workout-tracker.yml
D, [2017-08-08T15:32:38.970751 #3245] DEBUG -- : MgtCidr - {"type"=>"vpc_cidr", "tags"=>{"Name"=>"main"}}
D, [2017-08-08T15:32:38.971575 #3245] DEBUG -- : KeyName - devops-1
D, [2017-08-08T15:32:38.972031 #3245] DEBUG -- : DockerImageName - {"type"=>"docker_image_name", "image_name"=>"workout-tracker"}
D, [2017-08-08T15:32:38.972579 #3245] DEBUG -- : VpcId - {"type"=>"vpc", "tags"=>{"Name"=>"main"}}
D, [2017-08-08T15:32:38.973277 #3245] DEBUG -- : Zones - {"type"=>"zones", "tags"=>[{"Name"=>"public"}, {"Name"=>"private"}]}
D, [2017-08-08T15:32:38.974151 #3245] DEBUG -- : Subnets - {"type"=>"subnets", "tags"=>[{"Name"=>"public"}, {"Name"=>"private"}]}
D, [2017-08-08T15:32:38.977673 #3245] DEBUG -- : Loading module: cloudformation/templates/modules/base.json
D, [2017-08-08T15:32:38.981519 #3245] DEBUG -- : Loading module: cloudformation/templates/modules/vpc.json
D, [2017-08-08T15:32:39.093917 #3245] DEBUG -- : Stack exists(WorkoutTracker-0-0-8): false
D, [2017-08-08T15:32:39.094576 #3245] DEBUG -- : Creating stack
{% endhighlight %}

<p>
Most of this is debugging info that I use to keep track of what's going on.  The most important part here is the <b>rake</b> command, which consists of 4 parts:
</p>

<ul>
  <li><b>cf:launch</b> this is the rake target which contains the code I'm about execute</li>
  <li><b>workout-tracker</b> this is the profile yaml file I'm going to use to get things going.  This config file contains the template I'm going to use.</li>
  <li><b>0.0.8</b> version of the stack.  I use this to increase the velocity of my designs.  I don't have to wait for a stack to delete before creating a new one.  This also
    allows me to implement b/g at the infrastructure level.  Very handy.</li>
  <li><b>WorkoutTracker</b> the name of the CF stack.</li>
</ul>

<p>
The name of the CF stack ends up being <b>WorkoutTracker-0-0-8</b>.  Now I can use the version as a sort of "point in time" reference for where I'm at with the infrastructure code.
This is the most difficult way of producing CF stacks because it's forcing people to think of infrastructure as a gathering of versioned things, which is different than
what we're used to, which is something that lives in reality as a 1u component in a rack.  I personally prefer this model because I can create things faster and better here.
However, not everyone agrees with me on this one.
</p>

<p>
This does have it's draw backs, of course.  However, in one particular case called the <i>blast radius</i> argument, it's very easy to see how this would be better than traditional "non-versioned" layouts.
An example that demonstrates this would be how someone might argue that we should breakout the security groups for a given stack into their own stack.  This is fine, but the problem is
that if they are broken out, and multiple services are using a single SG, then if someone changes that SG, then everything that touches that SG is exposed.  This is a very short
example of how one change can have a "blasting" effect which "radiates" to more than we intend to.  Keeping the SGs inside the stack ensures that if something is changed,
then the only thing impacted by that change is the thing that is contained within the stack.
</p>

<h1>Implementation</h1>

<p>
I've used my code to create a stack, now we can start investigating what has been created.  First off I want to test to see if my ALB is working as I intend.
</p>

{% highlight bash %}
krogebry@ubuntu-secure:~/dev/workout_tracker$ curl Worko-EcsAL-W72TLYSV79IS-1289125696.us-east-1.elb.amazonaws.com/version
{"version":"0.5.0","build_time":"2017-08-08T13:52:02-0700","hostname":""}
{% endhighlight %}

<p>
We can see here that the ALB end point is working from my workstation here at home.
</p>

<p>
The <a href="/devops/code/2017-08-08/stack.json">stack</a> and <a href="/devops/code/2017-08-08/params.json">params</a> file are available for this demo.  Here's a detailed list
of what we're creating here.
</p>

<ul>
  <li>ASG that spins up a single EC2 instance.</li>
  <li>Security group for the EC2 instances.</li>
  <li>ALB and TargetGroup.</li>
  <li>Security group for the ALB entry point ( 0.0.0.0/0:80 )</li>
  <li>IAM roles for the EC2 instances as well as the ECS service.</li>
  <li>ECS service and task def.</li>
</ul>

<p>
The workout tracker implements JSON logging output, which is being sent through ECS to cloudwatch logs.  This doesn't do me any good at the moment, but having json
logs is just good stuff all around.
</p>

<img src="/devops/code/2017-08-08/logs.png" />

