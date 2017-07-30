---
layout: post
title:  "Starting the tattle trail project"
date:   2017-07-29 12:28:48 -0700
categories: cloudtrail
---

https://github.com/krogebry/tattletrail

<p>
Kicking off this project with a basic DSL in ruby which allows me to create a few rules.  I then evaluate these rules and create basic output that confirms I'm on the right path.
</p>

<ul>
  <li>Express simple rules which can be elvaluated in a ruby DSL manner.</li>
  <li>Output should contain the name of the rule that matched based on the rule and the threat level assigned o this rule</li>
  <li>Event data to see what's going on with the given rule.</li>
</ul>

<p>
I'm leaving out the obvious testing kit things.  The <b>performed</b> action isn't very smart yet.
</p>

<p>
There are currently two rules at play here.
</p>

<h1>Delete commands from the UI</h1>

<p>
A high-level security alert is anyone deleting a thing from the UI by hand.  This would indicate a user doing something manually outside of a scripted action.
The userAgent field will contain a specific string indicating that this action was done via the UI console.
</p>

<p>
This would be an example of a rule that might not be needed in the lower accounts like dev or maybe even stage, but would be very relevant in production.
</p>

{% highlight ruby %}
rule "Delete commands from the UI" do
  match_all
  threat_level  :high

  match 'eventName' do
    starts_with 'Delete'
  end

  performed 'by user' do
    by :user
    via :console
  end
end
{% endhighlight %}

<h1>New KeyPair was created by hand</h1>

<p>
This is another 'quick and dirty' rule that would indicate someone created a new keypair by hand via the UI.
</p>

{% highlight ruby %}
rule 'User creates a new key pair' do
  match_all
  threat_level  :high

  match 'eventName' do
    equals 'CreateKeyPair'
  end

  performed 'by user' do
    by :user
    via :console
  end
end
{% endhighlight %}



<h1>Report output</h1>

{% highlight bash %}
krogebry@ubuntu-secure:~/dev/tattletrail$ rake tt:report
D, [2017-07-29T18:16:26.258836 #3625] DEBUG -- : Creating base
D, [2017-07-29T18:16:26.258915 #3625] DEBUG -- : Starting reporter
D, [2017-07-29T18:16:26.259087 #3625] DEBUG -- : Creating rule: Delete commands from the UI
D, [2017-07-29T18:16:26.259173 #3625] DEBUG -- : Creating base
D, [2017-07-29T18:16:26.259217 #3625] DEBUG -- : Creating match rule for eventName
D, [2017-07-29T18:16:26.259315 #3625] DEBUG -- : Starting reporter
D, [2017-07-29T18:16:26.259378 #3625] DEBUG -- : Performed by: user
D, [2017-07-29T18:16:26.259410 #3625] DEBUG -- : Via: console
D, [2017-07-29T18:16:26.259533 #3625] DEBUG -- : Creating rule: User creates a new key pair
D, [2017-07-29T18:16:26.259622 #3625] DEBUG -- : Creating base
D, [2017-07-29T18:16:26.259709 #3625] DEBUG -- : Creating match rule for eventName
D, [2017-07-29T18:16:26.259782 #3625] DEBUG -- : Starting reporter
D, [2017-07-29T18:16:26.259845 #3625] DEBUG -- : Performed by: user
D, [2017-07-29T18:16:26.259932 #3625] DEBUG -- : Via: console

I, [2017-07-29T18:16:26.260846 #3625]  INFO -- : Delete commands from the UI level high
{"eventVersion"=>"1.05",
 "userIdentity"=>
  {"type"=>"Root",
   "principalId"=>"ACCOUNT_ID",
   "arn"=>"arn:aws:iam::ACCOUNT_ID:root",
   "accountId"=>"ACCOUNT_ID",
   "accessKeyId"=>"ASIAJTO6NK5FCFGA7GDA",
   "sessionContext"=>
    {"attributes"=>
      {"mfaAuthenticated"=>"true", "creationDate"=>"2017-07-30T00:15:11Z"}}},
 "eventTime"=>"2017-07-30T00:16:14Z",
 "eventSource"=>"ec2.amazonaws.com",
 "eventName"=>"DeleteRouteTable",
 "awsRegion"=>"us-east-1",
 "sourceIPAddress"=>"SOURCE_IP",
 "userAgent"=>"console.ec2.amazonaws.com",
 "requestParameters"=>{"routeTableId"=>"rtb-b89e9dc0"},
 "responseElements"=>{"_return"=>true},
 "requestID"=>"a2e704e0-5968-4132-985c-73ddfa0e7e3b",
 "eventID"=>"ded47154-0091-486b-94c1-d17b38216ebb",
 "eventType"=>"AwsApiCall",
 "recipientAccountId"=>"ACCOUNT_ID"}

I, [2017-07-29T18:16:26.264946 #3625]  INFO -- : User creates a new key pair level high
{"eventVersion"=>"1.05",
 "userIdentity"=>
  {"type"=>"Root",
   "principalId"=>"ACCOUNT_ID",
   "arn"=>"arn:aws:iam::ACCOUNT_ID:root",
   "accountId"=>"ACCOUNT_ID",
   "accessKeyId"=>"ACCESS_KEY_ID",
   "sessionContext"=>
    {"attributes"=>
      {"mfaAuthenticated"=>"true", "creationDate"=>"2017-07-25T20:07:17Z"}}},
 "eventTime"=>"2017-07-25T20:12:03Z",
 "eventSource"=>"ec2.amazonaws.com",
 "eventName"=>"CreateKeyPair",
 "awsRegion"=>"us-east-1",
 "sourceIPAddress"=>"SOURCE_IP",
 "userAgent"=>"console.ec2.amazonaws.com",
 "requestParameters"=>{"keyName"=>"devops-1"},
 "responseElements"=>
  {"requestId"=>"408ea540-ba83-4564-abf7-d7aa99dd8d10",
   "keyName"=>"devops-1",
   "keyFingerprint"=>
    "7f:b6:23:44:2b:e7:62:2e:4a:e2:70:d0:96:7f:06:f1:fd:38:60:81",
   "keyMaterial"=>"<sensitiveDataRemoved>"},
 "requestID"=>"408ea540-ba83-4564-abf7-d7aa99dd8d10",
 "eventID"=>"d9bbcb98-9a9c-4ab8-9a14-4382e3f5d3fc",
 "eventType"=>"AwsApiCall",
 "recipientAccountId"=>"ACCOUNT_ID"}
{% endhighlight %}

<h1>Next up</h1>

<ul>
	<li>Make the <b>performed</b> logic smarter.  Probably going to do more work around the specifics of a user actions versus an admin action.</li>
	<li>Introducing more random data into the processing to see what comes up.</li>
	<li>Introduce cloudformation actions that could be interesting</li>
</ul>


