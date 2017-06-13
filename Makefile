VERSION=0.5.0
USER_NAME=ec2-user
USER_ID=500

tag-ct-docker:
	docker tag redis:latest ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/redis:latest
	docker tag ennexa/resque-web:latest ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/resque-web:latest
	docker tag devops_mongodb:latest ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/mongodb:latest
	docker tag devops_resque-worker:latest ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/ct-compute:latest

push-ct-docker:
	$(aws ecr get-login)
	docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/redis:latest
	docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/resque-web:latest
	docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/mongodb:latest
	docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/ct-compute:latest
	
