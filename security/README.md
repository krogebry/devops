# Overview

Securing data is important.  Let's secure some shit.

# Goals

Using AWS::KMS + S3 SSE with rake to deliver secure data.

* Create KMS key.
* Create S3 bucket.
* Manage IAM credentials and access with CFT.
* Use rake task to grant temp access.
* Encrypt and Decrypt into git repo.
* Push encrypted bits up to s3 bucket using tagged KMS key.

# References

* MFA token for API calls: https://aws.amazon.com/blogs/security/how-to-enable-mfa-protection-on-your-aws-api-calls/
