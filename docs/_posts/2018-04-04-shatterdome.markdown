---
layout: post
title:  "Shatterdome"
date:   2018-04-04 10:00:00 -0700
categories: cloudformation 
---
{% assign docs = '/devops//code/2018-04-04' %}
{% assign bash = 'krogebry@ubuntu-secure:~$' %}

<h1>Overview</h1>

<p>
Shatterdome is my attempt at teaching how to build a platform tool.
</p>

<p>
In the course of my career I've run into more than a few companies that are working on building their own 
internal platform tooling.  In some cases this involves using terraform, and in those cases it's very clear 
that although terraform is a great tool, it has certain gaps that can't be addressed by it's particular methodology.
</p>

<p>
Terraform is a relativliy new player in the space of infrastructure orchistration and management.  Overall it's
a great tool for general use.  When you use tf you have the advantage of locking your infrastructure developers
into a very well defined declaritave space.  This is hugely benificial when you have platform teams that either
don't know much about how the cloud works, or they enjoy the security of knowing they have "bumpers" which keep
them safe.
</p>

<p>
This body of work is aimed at breaking out of the mindset of the restrictive declarative space.  Here we're 
going to explore how to use CloudFormation and ruby to create the least amount of code to create business
value quickly.  The goal here is to create something quick and slick that our customers ( usually internal
developers ) can start using quickly. 
</p>

<p>
It's entirely possible to take the idea of what's happening here and translate it to tf, and I highly
encourage you to look into that.  TF is like buying beer off the shelf, where as what we're doing here
is more like the home-brewed craft beer experience.  The outcome of this work will be a gem that we 
can package and ship to our customers so that they can easially and safely deploy and interact with 
the system that we've built.  We want our customers to be able to integrate this work into their
CI/CD workflows with as little effort on their part as possible.
</p>

<p>
I want to clearly state that this work isn't for everyone.  If you're just looking to belt out some
quick and dirty infrastructure bits to get people off your ass, then tf is your best bet.  However,
if you're looking to create something that is really outside of the box and absolutely a level
above the average, this is probably going to be very fun for you.  After all, some people long to 
craft the perfect beer, and others just want to get their buzz on.
</p>

<p>
Let's get crafting.
</p>

<h1>Workspace</h1>

<p>
We'll start this work by setting up a workspace to develop our platform.  Most of this work has been done
in a project that I'm codenaming <b>Shatterdome</b> after my favorite movies <b>Pacfiic Rim</b>.
</p>

<p>
Eventually we're going to have a bin file that we can execute on the command line.  We'll install
this bin via the gem package.  You can do the same kind of thing with python or just about any
other language.
</p>

<p>
The bin is going to follow a command pattern in the form of <b>noun</b> <i>verb</i>.  For example:
</p>

<div class="code">
{{ bash }} shatterdome cluster create
</div>

<p>
In this case the <b>noun</b> is cluster and the <i>verb</i> is create.  We'll have two nouns to start
with, but we might expand beyond that later.
</p>

<ol>
    <li>cluster: this is essentially the ECS cluster, with associated ASG, and CW triggers.</li>
    <li>service: a service is a collection of things that we're going to run on a cluster.</li>
</ol>

<h2>Cluster</h2>

<ul>
    <li>AutoScale group</li>
    <li>IAM policies</li>
    <li>ECS cluster</li>
</ul>

<h2>Service</h2>

<ul>
    <li>ECS service</li>
    <li>ECS tasks</li>
    <li>ALB or NLB</li>
</ul>


