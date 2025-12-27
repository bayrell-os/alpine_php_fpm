#!/bin/bash

SCRIPT=$(readlink -f $0)
SCRIPT_PATH=`dirname $SCRIPT`
BASE_PATH=`dirname $SCRIPT_PATH`

RETVAL=0
VERSION=8.3
SUBVERSION=20251227
IMAGE="alpine_php_fpm"
TAG=`date '+%Y%m%d_%H%M%S'`

case "$1" in
	
	test)
		DOCKER_BUILDKIT=0 docker build ./ -t bayrell/$IMAGE:$VERSION-$TAG --file Dockerfile
	;;
	
	amd64)
		export DOCKER_DEFAULT_PLATFORM=linux/amd64
		docker build ./ -t bayrell/$IMAGE:$VERSION-$SUBVERSION-amd64 \
			--file Dockerfile --build-arg ARCH=amd64/
	;;
	
	arm64v8)
		export DOCKER_DEFAULT_PLATFORM=linux/arm64/v8
		docker build ./ -t bayrell/$IMAGE:$VERSION-$SUBVERSION-arm64v8 \
			--file Dockerfile --build-arg ARCH=arm64v8/
	;;
	
	arm32v7)
		export DOCKER_DEFAULT_PLATFORM=linux/arm/v7
		docker build ./ -t bayrell/$IMAGE:$VERSION-$SUBVERSION-arm32v7 \
			--file Dockerfile --build-arg ARCH=arm32v7/
	;;
	
	manifest)
		rm -rf ~/.docker/manifests/docker.io_bayrell_$IMAGE_NAME-*
		
		docker tag bayrell/$IMAGE:$VERSION-$SUBVERSION-amd64 bayrell/$IMAGE:$VERSION-amd64
		docker tag bayrell/$IMAGE:$VERSION-$SUBVERSION-arm64v8 bayrell/$IMAGE:$VERSION-arm64v8
		docker tag bayrell/$IMAGE:$VERSION-$SUBVERSION-arm32v7 bayrell/$IMAGE:$VERSION-arm32v7
		
		docker push bayrell/$IMAGE:$VERSION-$SUBVERSION-amd64
		docker push bayrell/$IMAGE:$VERSION-$SUBVERSION-arm64v8
		docker push bayrell/$IMAGE:$VERSION-$SUBVERSION-arm32v7
		
		docker push bayrell/$IMAGE:$VERSION-amd64
		docker push bayrell/$IMAGE:$VERSION-arm64v8
		docker push bayrell/$IMAGE:$VERSION-arm32v7
		
		docker manifest create bayrell/$IMAGE:$VERSION-$SUBVERSION \
			--amend bayrell/$IMAGE:$VERSION-$SUBVERSION-amd64 \
			--amend bayrell/$IMAGE:$VERSION-$SUBVERSION-arm64v8 \
			--amend bayrell/$IMAGE:$VERSION-$SUBVERSION-arm32v7
		docker manifest push bayrell/$IMAGE:$VERSION-$SUBVERSION
		
		docker manifest create bayrell/$IMAGE:$VERSION \
			--amend bayrell/$IMAGE:$VERSION-amd64 \
			--amend bayrell/$IMAGE:$VERSION-arm64v8 \
			--amend bayrell/$IMAGE:$VERSION-arm32v7
		docker manifest push bayrell/$IMAGE:$VERSION
	;;
	
	upload-github)
		docker tag bayrell/$IMAGE:$VERSION-$SUBVERSION-arm64v8 \
			ghcr.io/bayrell-os/$IMAGE:$VERSION-$SUBVERSION-arm64v8
		
		docker tag bayrell/$IMAGE:$VERSION-$SUBVERSION-arm32v7 \
			ghcr.io/bayrell-os/$IMAGE:$VERSION-$SUBVERSION-arm32v7
		
		docker tag bayrell/$IMAGE:$VERSION-$SUBVERSION-amd64 \
			ghcr.io/bayrell-os/$IMAGE:$VERSION-$SUBVERSION-amd64
		
		docker push ghcr.io/bayrell-os/$IMAGE:$VERSION-$SUBVERSION-amd64
		docker push ghcr.io/bayrell-os/$IMAGE:$VERSION-$SUBVERSION-arm32v7
		docker push ghcr.io/bayrell-os/$IMAGE:$VERSION-$SUBVERSION-arm64v8
		
		docker manifest create --amend \
			ghcr.io/bayrell-os/$IMAGE:$VERSION-$SUBVERSION \
			ghcr.io/bayrell-os/$IMAGE:$VERSION-$SUBVERSION-amd64 \
			ghcr.io/bayrell-os/$IMAGE:$VERSION-$SUBVERSION-arm32v7 \
			ghcr.io/bayrell-os/$IMAGE:$VERSION-$SUBVERSION-arm64v8
		docker manifest push --purge ghcr.io/bayrell-os/$IMAGE:$VERSION-$SUBVERSION
		
		docker tag bayrell/$IMAGE:$VERSION-arm64v8 \
			ghcr.io/bayrell-os/$IMAGE:$VERSION-arm64v8
		
		docker tag bayrell/$IMAGE:$VERSION-arm32v7 \
			ghcr.io/bayrell-os/$IMAGE:$VERSION-arm32v7
		
		docker tag bayrell/$IMAGE:$VERSION-amd64 \
			ghcr.io/bayrell-os/$IMAGE:$VERSION-amd64
		
		docker push ghcr.io/bayrell-os/$IMAGE:$VERSION-amd64
		docker push ghcr.io/bayrell-os/$IMAGE:$VERSION-arm32v7
		docker push ghcr.io/bayrell-os/$IMAGE:$VERSION-arm64v8
		
		docker manifest create --amend \
			ghcr.io/bayrell-os/$IMAGE:$VERSION \
			ghcr.io/bayrell-os/$IMAGE:$VERSION-amd64 \
			ghcr.io/bayrell-os/$IMAGE:$VERSION-arm32v7 \
			ghcr.io/bayrell-os/$IMAGE:$VERSION-arm64v8
		docker manifest push --purge ghcr.io/bayrell-os/$IMAGE:$VERSION
	;;
	
	upload-image)
		
		if [ -z "$2" ] || [ -z "$3" ]; then
			echo "Type:"
			echo "$0 upload-image $VERSION raspa 172"
			echo "  $VERSION - version"
			echo "  raspa - ssh host"
			echo "  172 - bandwidth KiB/s"
			exit 1
		fi
		
		image=$IMAGE
		version=$2
		ssh_host=$3
		bwlimit=""
		
		if [ ! -z "$4" ]; then
			bwlimit=$4
		fi
		
		mkdir -p images
		
		if [ ! -f ./images/$image-$version.tar.gz ]; then
			echo "Save image"
			docker image save bayrell/$image:$version | gzip \
				> ./images/$image-$version.tar.gz
		fi
		
		echo "Upload image"
		ssh $ssh_host "mkdir -p ~/images"
		ssh $ssh_host "yes | rm -f ~/images/$image-$version.tar.gz"
		
		if [ ! -z "$bwlimit" ]; then
			time rsync -aSsuh \
				--info=progress2 \
				--bwlimit=$bwlimit \
				./images/$image-$version.tar.gz \
				$ssh_host:images/$image-$version.tar.gz
		else
			time rsync -aSsuh \
				--info=progress2 \
				./images/$image-$version.tar.gz \
				$ssh_host:images/$image-$version.tar.gz
		fi
		
		echo "Load image"
		ssh $ssh_host "docker load -i ~/images/$image-$version.tar.gz"
	;;
	
	all)
		$0 amd64
		$0 arm64v8
		$0 arm32v7
		$0 manifest
	;;
	
	getcomposer)
		cd files/usr/bin

		rm -f composer

		php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
		php -r "if (hash_file('sha384', 'composer-setup.php') === 'c8b085408188070d5f52bcfe4ecfbee5f727afa458b2573b8eaaf77b3419b0bf2768dc67c86944da1544f06fa544fd47') { echo 'Installer verified'.PHP_EOL; } else { echo 'Installer corrupt'.PHP_EOL; unlink('composer-setup.php'); exit(1); }"
		php composer-setup.php
		php -r "unlink('composer-setup.php');"

		mv composer.phar composer
	;;
	
	*)
		echo "Usage: $0 {amd64|arm64v8|arm32v7|manifest|all|test}"
		RETVAL=1

esac

exit $RETVAL

