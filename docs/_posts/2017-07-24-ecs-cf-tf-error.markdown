---
layout: post
title:  "An annoying error on AWS with ECS and Cloudformation and Terraform"
date:   2017-07-24 12:28:48 -0700
categories: cloudformation
---

<p>
This f'ing error was causing me much consternation recently.
</p>

<blockquote>
ECSService Unable to assume role and validate the listeners configured on your load balancer. Please verify the role being passed has the proper permissions.
</blockquote>

<p>
This is the error when doing the same with terraform:
</p>

<blockquote>
aws_ecs_service.ecs_service: InvalidParameterException: Unable to assume role and validate the specified targetGroupArn. Please verify that the ECS service role being passed has the proper permissions. status code: 400, request id: blah-blah-blah
</blockquote>

<p>
Here's the service definition for the ECS chunk:
</p>

{% highlight json %}
{
  "service": {
    "Type": "AWS::ECS::Service",
    "DependsOn": [
      "ALBListener",
      "ECSAutoScalingGroup",
      "ECSServiceRole",
      "EcsTargetGroup",
      "EC2Role",
      "taskdefinition"
    ],
    "Properties": {
      "Cluster": {
        "Ref": "ECSCluster"
      },
      "DesiredCount": "1",
      "LoadBalancers": [
        {
          "ContainerName": "wt-api",
          "ContainerPort": "8080",
          "TargetGroupArn": {
            "Ref": "EcsTargetGroup"
          }
        }
      ],
      "Role": {
        "Ref": "ECSServiceRole"
      },
      "TaskDefinition": {
        "Ref": "taskdefinition"
      }
    }
  }
}
{% endhighlight %}

<p>
And here's my service role definition:
</p>

{% highlight json %}
{
  "ECSServiceRole": {
    "Type": "AWS::IAM::Role",
    "Properties": {
      "AssumeRolePolicyDocument": {
        "Statement": [
          {
            "Effect": "Allow",
            "Principal": {
              "Service": [
                "ecs.amazonaws.com"
              ]
            },
            "Action": [
              "sts:AssumeRole"
            ]
          }
        ]
      },
      "Path": "/",
      "Policies": [
        {
          "PolicyName": "ecs-service",
          "PolicyDocument": {
            "Statement": [
              {
                "Effect": "Allow",
                "Action": [
                  "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
                  "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
                  "ec2:Describe*",
                  "ec2:AuthorizeSecurityGroupIngress",
                  "elasticloadbalancing:DeregisterTargets",
                  "elasticloadbalancing:Describe*",
                  "elasticloadbalancing:RegisterInstancesWithLoadBalancer"
                ],
                "Resource": "*"
              }
            ]
          }
        }
      ]
    }
  }
}
{% endhighlight %}

<p>
And here's my terraform chunk to do the service:
</p>

{% highlight terraform %}
resource "aws_ecs_service" "ecs_service" {  
	name = "ecs_service-${var.env_name}-${var.stack_version}"  
	cluster = "${aws_ecs_cluster.ecs_cluster.id}"  
	iam_role = "${aws_iam_role.service_role.arn}"  
	depends_on = ["aws_iam_policy.service_policy"]  
	desired_count = 1  
	task_definition = "${aws_ecs_task_definition.app.arn}"
  load_balancer {    
		container_name = "app_task"    
		container_port = 8080    
		target_group_arn = "${aws_alb_target_group.target-group.arn}"  
	}
}
{% endhighlight %}

<p>
The IAM stuff is basically the same for the tf chunk here.
</p>

<p>
Long story short here, this is a problem when you try to reference the wrong <b>TargetGroupArn</b>.  When I was getting the error I was actually pointing to the ALB instead of the TargetGroup.  Seems obvious, but TF's string interrelation sucks in that it doesn't do embedded variables.
</p>

<p>
The error from TF and the error from CF were both equally vague and not very helpful at all.  Hope this helps someone else out there.
</p>
