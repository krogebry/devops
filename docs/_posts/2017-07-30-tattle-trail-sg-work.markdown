---
layout: post
title:  "Creating simple security group rules."
date:   2017-07-30 12:28:48 -0700
categories: cloudtrail
---

<a href="https://github.com/krogebry/tattletrail">Code</a>

<h1>Security group rules</h1>

<p>
Introduced a handler to <b>high</b> alert anyone who has changed a security group via the UI.
</p>

{% highlight ruby %}
rule 'User opens TCP to world' do
  match_all
  threat_level  :high

  match 'eventName' do
    equals 'AuthorizeSecurityGroupIngress'
  end

  performed 'by user' do
    by :user
    via :console
  end

  opens_cidr 'world' do
    cidr '0.0.0.0/0'
  end
end
{% endhighlight %}

<p>
In this example we would see a <span style="color:red;">high</span> alert if someone has opened all TCP/UDP to 0.0.0.0/0.
</p>

<p>
Here's another example of the idea.  In this example we're excluding rules that pertain to :80 and :433.  This rule also specifically targets actions that were performed
via a cloudformation script.
</p>

<p>
This would catch anyone who has launched a CF stack which has an obvious security problem.  In this case that might be something like :22 from 0.0.0.0/0 or basically
any combination of ports that isn't :80 or :443 and is open to the world.
</p>

{% highlight ruby %}
rule 'Cloudformation script opens TCP to world' do
  match_all
  threat_level  :medium

  match 'eventName' do
    equals 'AuthorizeSecurityGroupIngress'
  end

  performed 'by user' do
    by :user
    via :cloudformation
  end

  opens_cidr 'world' do
    cidr '0.0.0.0/0'
    ignore_port 80
    ignore_port 443
  end
end
{% endhighlight %}

<h1>More rules files</h1>

<p>
This version also improves the rule ingestion in that we can now have many files in the <b>./rules/</b> dir.
</p>

{% highlight ruby %}
    rules = ""
    Dir.glob(File.join('rules/*.rb')).each do |filename|
      rules << File.read(filename)
    end
{% endhighlight %}

<h1>Slightly better output</h1>

{% highlight bash %}
D, [2017-07-30T12:48:04.220619 #6839] DEBUG -- : Creating match rule for world
I, [2017-07-30T12:48:04.223147 #6839]  INFO -- : Cloudformation script opens TCP to world
I, [2017-07-30T12:48:04.223776 #6839]  INFO -- : krogebry	2017-07-30 04:28:46 UTC
I, [2017-07-30T12:48:04.224130 #6839]  INFO -- : Cloudformation script opens TCP to world
I, [2017-07-30T12:48:04.224355 #6839]  INFO -- : krogebry	2017-07-30 04:28:46 UTC
{% endhighlight %}

<h1>Next up</h1>

<p>
I seem to have a pattern of completely ignoring my "next up" section.
</p>

<ul>
	<li>Grading system which can produce A,B,C,D,Failing grades based on the execution of the rules.</li>
	<li>Better output reporting</li>
	<li>MFA type rules</li>	
  <li>More work on gathering the data</li>
</ul>


