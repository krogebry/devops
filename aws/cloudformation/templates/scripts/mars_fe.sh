#!/bin/bash -xe
/opt/aws/bin/cfn-init -v --stack ${AWS::StackName} --resource MarsFEInstances --region ${AWS::Region}
mkdir -p /var/log/chef
aws s3 cp --sse-kms-key-id ${KMSKeyId} --sse 'aws:kms' s3://${S3BucketName}/chef-server/devops/devops-validator.pem /etc/chef/validation.pem --region ${AWS::Region}
chef-client -j /etc/chef/dna.json -E ${ChefEnvName}
/opt/aws/bin/cfn-signal -e $?  --stack ${AWS::StackName} --resource MarsFEASG --region ${AWS::Region}
