Credits

Shamelessly ripped off from here.

Goal

Create an encryption pipeline that satisfies the "90%" rule which is usable and easy for end users to consume and utilize.

Value statement

Our customers will have secrets that they want to keep secret and away from hackers. This is also part of our drive to think about security "early and often."

Tools used

Docker + docker-compose
Rancher + rancher-compose
AWS::KMS
AWS::S3
Workflow

The idea here is to allow our users, or anyone for that matter, to store secrets in an encrypted way, then allow rancher to pass those secrets securely into a docker container. There are many ways of doing this and one good way that I've found that seems to work.

Let's start off by looking at how this is done in the wild using environment variables. We can look at things like jenkins and GoCD as good examples of how this works. The service has an ssl cert that is generated when the service is initialized for the first time. That secret key is hidden until there is a need to use it. It's used when a user of the service creates a secret configuration value. This secret value is encrypted into the database using the private key, then decrypted with that same key when it's invoked.

This allows us to store secrets like ssh keys or passwords in our CI/CD system without worrying about these secrets being exposed to other users of the system or malicious actors.

The docker project is working on a way to store environment variables in a similar type of way, however, at present we don't really have a reliable way of storing anything in an encrypted manner. Rancher is in a similar state.

People in the field are doing the best they can, but most of what is happening appears to be a hack until a better solution comes about.

The solution that I have here uses KMS and S3 to store an encrypted environment file using SSE ( Server Side Encryption ).

Let's look at a sample workflow that uses an RDS setup. In this example the operators ( ops ) will be creating a simple RDS instance, then handing the credentials over to the client team ( we'll use Snacks for this example ). The Snacks team would then use this workflow to manage their secrets.

Ops create RDS. This produces three key artifacts: u/p/h ( username/password/hostname ).
Ops encrypts this file into a repo for storage ( ops KMS key + gpg ).
Ops sends the unencrypted file to s3 using SSE and the *client* KMS key.
Ops negotiates with security team for appropriate IAM roles and rights.
Ops provides Snacks team lead with scripts that can pull down the u/p/h payload using KMS.
Functionally this works by using the s3 SSE extensions to encrypt the file on the s3 side. This means that we could pull down the u/p/h file without using SSE and all we'd see is garbage. We have to use the SSE+KMS system in order to see the plaintext data.

Using a client key for Snacks ( prod/dev/qa/etc... ) would further isolate the security profile by providing a KMS key for each environment that could be used for multiple payloads.

We could go the extra step of creating IAM security profiles for the s3 access as well.

s3 object access to the encrypted data
KMS access for the services to decrypt the data.
Example

Snacks is a new service running on the PaaS. It's a complicate service that has many moving parts and requires encrypted secrets. Specifically we'll be creating an RDS instance for their use and setting up their u/p/h payload.

Snacks is a ruby application using sinatra. The team will be delivering docker images to rancher.

This system works by tapping into a neat little feature of dockers Entrypoint functionality. We've communicated to the Snacks-TL ( Tech Lead ) our process for handling secret data. They've made the changes to their docker CMD command as such:

CMD ["./in_s3_env", "mounts/api.rb"]
The in_s3_env script is a wrapper for executing s3_kms_env. We wrap the s3_kms_env script because we don't want the output sent to STD[ERR,OUT], instead we want it piped into the CMD call, which will effectively pass whatever we output into the next command, which, in this case is mounts/api.rb.

mounts/api.rb is the only script that needs access to the u/p/h payload.

We assume that we've sent the env file to our client bucket: *s3://tw-snacks/dev/env*. If we did a quick and dirty s3 client that pulled down that file and tried to echo the content without using SSE+KMS we'd see this:

$ ./s3_kms_env
 "ys\xA6\xBF\u0003\xB0t\xB8\xEC$\xD0-\xFF\x86\xAA\xBC\u000Ek\x9F\x92\u0000\xA4*\xB6\xB4\u0018\x80t\xCA\u0019N\xB0\x8F\v\xD0=\b-O\u001C\xD5F\xA5f\x95(q\xA0"
However, if we did use SSE+KMS, we'd see something like this:

$ ./s3_kms_env
 DB_USERNAME='root'
 DB_PASSWORD='orange1'
 DB_HOSTNAME='blah.amazon.com'
When rancher spins up the service container it will first run in_s3_env which will wrap s3_kms_env the output creates:

export DB_USERNAME='root' export DB_PASSWORD='orange1' export DB_HOSTNAME='blah.amazon.com' mounts/api.rb
As far as I can tell, this final expressed command isn't piped to anything but the application and isn't exposed anywhere in the API or the logs.

If we like this solution, we could possibly expand the scope of the *s3_kms_env* script to include more things:

Failure conditions for s3/kms access failures.
Connection failures.
Additional safety checks.
Callbacks to an internal ops service for logging/monitoring/alerting ( l/m/a )
Logging into splunk, then splunk dashboards showing access of given credentials.
Cloudwatch alarms.
Reference material

Create a KMS key. Now let us take a look at the policy:

$ aws kms get-key-policy --key-id 8c60a5bd-KEY_ID-ee17391d7499 --policy-name default|jq '.Policy'|ruby -e "require 'json';puts JSON::parse(STDIN.read)"
 {
 "Version" : "2012-10-17",
 "Id" : "auto-codecommit-2",
 "Statement" : [ {
 "Sid" : "Allow access through CodeCommit for all principals in the account that are authorized to use CodeCommit",
 "Effect" : "Allow",
 "Principal" : {
 "AWS" : "*"
 },
 "Action" : [ "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey" ],
 "Resource" : "*",
 "Condition" : {
 "StringEquals" : {
 "kms:ViaService" : "codecommit.us-east-1.amazonaws.com",
 "kms:CallerAccount" : "ACCOUNT_ID"
 }
 }
 }, {
 "Sid" : "Allow direct access to key metadata to the account",
 "Effect" : "Allow",
 "Principal" : {
 "AWS" : "arn:aws:iam::ACCOUNT_ID:root"
 },
 "Action" : [ "kms:Describe*", "kms:Get*", "kms:List*" ],
 "Resource" : "*"
 } ]
 }

This should be the same as doing the work via the ruby aws cli, but for some doesn't.

 aws configure set default.s3.signature_version s3v4
 aws --profile project-team s3 cp --sse "aws:kms" --sse-kms-key-id 7c3446d-KEY_ID-430f03 s3://tw-snacks/dev/env /tmp/env
 aws --profile project-team s3 cp --sse "aws:kms" --sse-kms-key-id 7c3446d-KEY_ID-430f03 cp /tmp/env s3://tw-snacks/dev/env
