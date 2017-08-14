---
layout: post
title:  "Implementing security with Workout Tracker using S3 SSE and KMS"
date:   Tue Aug  9 11:10:33 PDT 2017
categories: cloudformation
---

<h1>Overview</h1>

<p>
Security is probably my least favorite topic all around.  In this post I'm going to explore how we can use AWS S3 with KMS to lock down our secrets.
I'm choosing to go with this method over something like vault because I think this method is probably the easiest and covers the most use cases for
what we want here.  My goal with this work is to simply secure the secrets for my application.
</p>

<h2>Goals</h2>

<ul>
  <li>Secure secrets that can be exposed as environment variables and used at run time.</li>
  <li>Prevent any exposure of these secrets through things like log files.</li>
  <li>Give the operations teams a way to manage the secrets</li>
</ul>

<h1>Implementation</h1>

<p>
We start this by creating a script that we'll use as the entry point.
</p>

<div><b>aws_sse_s3.sh</b></div>
{% highlight bash %}
#!/bin/bash
$(/opt/wt/bin/get_s3_env)
/opt/wt/bin/wt-api $@
{% endhighlight %}

<p>
The implementation is used in docker as such:
</p>

{% highlight docker %}
ENTRYPOINT ["/opt/wt/bin/aws_sse_s3.sh"]
{% endhighlight %}

<p>
Next the <b>get_s3_env</b> script will do the work to export the environment variables from the file we pull down from s3.
</p>

<div><b>get_s3_env</b></div>
{% highlight ruby %}
#!/usr/bin/env ruby
# https://gist.github.com/themoxman/1d137b9a1729ba8722e4
require 'aws-sdk'
s3_client = Aws::S3::Client.new(region: 'us-east-1')
kms_client = Aws::KMS::Client.new(region: 'us-east-1')

# retrieve cmk key id
aliases = kms_client.list_aliases.aliases
key = aliases.find { |alias_struct| alias_struct.alias_name == format("alias/workout-tracker-%s", ENV['ENV_NAME'] }
key_id = key.target_key_id

# encryption client
s3_encryption_client = Aws::S3::Encryption::Client.new(
  client: s3_client,
  kms_key_id: key_id,
  kms_client: kms_client,
)

response = s3_encryption_client.get_object(bucket: 'chime-secrets', key: '.env')
response.body.read.each_line { |line| exports << "export #{line.chomp};" }
{% endhighlight %}

<p>
This process allows us to create entry points for operations to modify the thing that gets our secrets, and exposes them to the applicaiton.
This way, all the application has to do is incorporate environment variables for secrets.  Obviously there are different ways of doing this
for example baking vault integration into the application.
</p>

<p>
What I've found is that sometimes we need easy, simple ways to integrate our secrets.  This is a super simple way of giving us a channel into
secrets management that does the job, and allows us a way to replace the system later.  This is a great solution for a rev1 release where
we're just trying to get things up and rocking.  
</p>

<h1>Ops</h1>

<p>
Now let's talk about how we allow our operations engineers to manage the secrets.
I usually wrap these things into Rake tasks rather than Make tasks because API's are fun.
I'm using a very simple, generic function to encapsulate the logic which gives me an encrypted s3 client using a specific KMS key.
</p>

{% highlight ruby %}
def get_enc_client
  creds = Aws::SharedCredentials.new()
  s3_client = Aws::S3::Client.new(region: ENV['AWS_DEFAULT_REGION'], credentials: creds)
  kms_client = Aws::KMS::Client.new(region: ENV['AWS_DEFAULT_REGION'], credentials: creds)

  aliases = kms_client.list_aliases.aliases
  key = aliases.find { |alias_struct| alias_struct.alias_name == format("alias/workout-tracker-%s", ENV['ENV_NAME']) }
  key_id = key.target_key_id

  Aws::S3::Encryption::Client.new(
    client: s3_client,
    kms_key_id: key_id,
    kms_client: kms_client
  ) 
end
{% endhighlight %}

<p>
As you can see, the KMS key alias is a calculated string using a variable name which is passed in from the docker environment.
</p>

<p>
Now we implement this with our two tasks: <b>secrets:push</b> <b>secrets:pull</b>.
</p>

{% highlight ruby %}
namespace :secrets do

  desc "Push secrets"
  task :push do |t,args|
    mk_secrets_dir
    s3_enc_client = get_enc_client()
    s3_enc_client.put_object(
      key: '%s/env' % ENV['ENV_NAME'],
      body: File.read('/tmp/secrets/workout-tracker/%s/env' % ENV['ENV_NAME']),
      bucket: 'workout-tracker'
    )
  end

  desc "Pull secrets"
  task :pull do |t,args|
    mk_secrets_dir
    s3_enc_client = get_enc_client()
    File.open('/tmp/secrets/workout-tracker/%s/env' % ENV['ENV_NAME'], 'w') do |f|
      s3_enc_client.get_object(
        key: '%s/env' % ENV['ENV_NAME'],
        bucket: 'workout-tracker'
      ) do |chunk|
        f.write(chunk)
      end
    end
  end

end
{% endhighlight %}

<h1>How it works</h1>

<p>
When we push a secret up to S3 we're using the KMS key for this environment, then we're pushing the local file to s3 using SSE and KMS.
We can test the encryption by pulling the file down from s3 without using SSE.
</p>

{% highlight ruby %}
$ aws s3 cp s3://workout-tracker/dev/env ./test
download: s3://workout-tracker/dev/env to ./test                 
$ cat test 
mIpRr??
??^?-
{% endhighlight %}

<p>
This shows that if someone was able to somehow access the s3 object, they wouldn't be able to see the contents without also being
able to access the KMS key.
</p>

