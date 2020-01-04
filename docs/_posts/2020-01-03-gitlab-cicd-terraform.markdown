---
layout: post
title:  "Terraform workspaces wit gitlab CICD"
date:   2020-1-3 11:00:00 -0700
categories: terraform gitlab cicd
---
<h1>Overview</h1>

<p>
Using terraform workspaces with a little python code and gitlab cicd pipelines to create a dynamic, interesting
pipeline.
</p>

<h4>Use case</h4>

Company: <a href="https://renovo.auto">Renovo</a> 

<p>
We wanted to create a single terraform manifest that could express complicated infrastructure requirements with
environmental deltas.  A single, simple implementation, but with each environment express uniqueness based on the
environmental needs.
</p>

{% highlight shell %}
➜  raleigh git:(master) terraform workspace list
* default

➜  raleigh git:(master) *terraform workspace new stage*
Created and switched to workspace "stage"!

You're now on a new, empty workspace. Workspaces isolate their state,
so if you run "terraform plan" Terraform will not see any existing state
for this configuration.
➜  raleigh git:(master) terraform workspace new production
Created and switched to workspace "production"!

You're now on a new, empty workspace. Workspaces isolate their state,
so if you run "terraform plan" Terraform will not see any existing state
for this configuration.
➜  raleigh git:(master) terraform workspace list          
  default
* production
  stage
{% endhighlight %}

