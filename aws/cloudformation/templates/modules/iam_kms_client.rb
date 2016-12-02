{
  "Parameters": { },


  "Resources": {

    "InstanceRole": {
      "Type": "AWS::IAM::Role",
      "Properties": {
        "AssumeRolePolicyDocument": {
          "Version" : "2012-10-17",
          "Statement": [ {
            "Effect": "Allow",
            "Principal": { "Service": [ "ec2.amazonaws.com" ] },
            "Action": [ "sts:AssumeRole" ]
          } ]
        },
        "Path": "/"
      }
    },

    "RolePolicies": {
      "Type": "AWS::IAM::Policy",
      "Properties": {
        "PolicyName": "root",
        "PolicyDocument": {
          "Version" : "2012-10-17",
          "Statement": [{
            "Effect": "Allow",
            "Action": "*",
            "Resource": "*"
          }]
        },
        "Roles": [{ "Ref": "InstanceRole" }]
      }
    },

    "RootInstanceProfile": {
      "Type": "AWS::IAM::InstanceProfile",
      "Properties": {
        "Path": "/",
        "Roles": [{ "Ref": "InstanceRole" }]
      }
    }

  }

}

