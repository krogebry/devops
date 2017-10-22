#!/bin/bash -xe
/opt/aws/bin/cfn-init -v --stack ${AWS::StackName} --resource ChefServerLC --region ${AWS::Region}

# wget "https://s3.amazonaws.com/devops-ct-main/chef-server-core-12.16.14-1.el7.x86_64.rpm"
# rpm -i chef-server-core-12.16.14-1.el7.x86_64.rpm
# chef-server-ctl reconfigure 
# chef-server-ctl user-create bkroger Bryan Kroger bryan.kroger@gmail.com '${Password}' --filename /etc/chef/bkroger.pem 
# chef-server-ctl org-create devops 'DevOps Central' --association_user bkroger --filename /etc/chef/devops-validator.pem

# pip install --upgrade awscli 

# KMS_KEY_ID=`aws --region ${AWS::Region} kms list-aliases | jq '.Aliases[] | select(.AliasName == "alias/devopskey_${InfStackVersion})|.AliasArn'|sed 's/\"//g'
# aws s3 cp --sse-kms-key-id \$\{KMS_KEY_ID\} --sse 'aws:kms' /etc/chef/bkroger.pem s3://${S3BucketName}/chef-server/devops/ --region ${AWS::Region}
# aws s3 cp --sse-kms-key-id \$\{KMS_KEY_ID\} --sse 'aws:kms' /etc/chef/devops-validator.pem s3://${S3BucketName}/chef-server/devops/ --region ${AWS::Region}

/opt/aws/bin/cfn-signal -e $?  --stack ${AWS::StackName} --resource ChefServerASG --region ${AWS::Region}
