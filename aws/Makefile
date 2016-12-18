##
# Make the go stuff.
##

BINARY=recon
PROJECT=recon

VERSION="0.1.0"
BUILD_TIME=`date +%FT%T%z`

LDFLAGS=-ldflags "-X main.Version=${VERSION} -X main.BuildTime=${BUILD_TIME}"

clean_up: | clean build dc_build dc_up

dc_build:
	docker-compose build

dc_up:
	docker-compose up

deps:
	# go get github.com/go-sql-driver/mysql
	go get github.com/go-sql-driver/mysql
	# go get github.com/Sirupsen/logrus
	go get github.com/aws/aws-sdk-go
	go get github.com/aws/aws-sdk-go/service/dynamodb

	#go get github.com/aws/aws-sdk-go/aws
	#go get github.com/aws/aws-sdk-go/aws/session
	#go get github.com/aws/aws-sdk-go/service/s3/s3manager

build:
	go build ${LDFLAGS} -o bin/${BINARY} src/github.com/krogebry/${PROJECT}/*.go

push:
	docker tag wt-api:${VERSION} krogebry/wt-api:latest
	docker push krogebry/wt-api

docker_image:
	docker build -t wt-api:${VERSION} -f docker/wt-api .

clean:
	if [ -f bin/${BINARY} ] ; then rm bin/${BINARY} ; fi

create_db_vol:
	docker volume create --name=database

docker_cleanup:
	# Kill all running containers.
	#docker kill $(docker ps -q)
	# Delete all stopped containers.
	#docker rm $(docker ps -a -q)
	# Delete all untagged images.
	#docker rmi $(docker images -q -f dangling=true)
