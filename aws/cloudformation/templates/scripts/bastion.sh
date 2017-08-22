#!/bin/bash -xe
/opt/aws/bin/cfn-init -v --stack ${AWS::StackName} --resource BastionInstances --region ${AWS::Region}
/opt/aws/bin/cfn-signal -e $?  --stack ${AWS::StackName} --resource BastionASG --region ${AWS::Region}
