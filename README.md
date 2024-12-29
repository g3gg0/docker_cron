
# Docker cron runner

tl;dr: A simple helper script to execute containers periodically

## About

This project is a lightweight and straightforward helper designed to enhance my Docker setup by automating the periodic execution of specific containers.

### The Problem

All my Docker stacks contain one or more stack-specific backup containers that need to run on a daily, weekly, or even monthly basis. Additionally, the Certbot for updating certificates must also be executed periodically. Unfortunately, I couldn't find a simple, working solution. Many available options were either too complex or didn’t work out of the box. So, I built my own cron runner.

If you manage this manually using crontab (what i did intially), you might overlook some details or need to back up this setup as well or end up editing too many places just to add another backup.

### The Solution

To avoid this, I decided to use a "runner" container that executes all backup containers with a specific label. It’s nothing fancy or complex—just an internal helper. I’m sharing it with you as an optional utility. Take it or leave it.

### Why Use This?

This utility is designed to be simple and practical—nothing fancy or overly engineered. It works reliably within my internal Docker environment.

I reworked it, put it into a docker container on its own and am sharing it as an optional tool that you can use if it suits your needs.
Take it or leave it - it's up to you.

## Setup

Create a new stack with this compose 

    services:
      cron:
        image: ghcr.io/g3gg0/docker_cron:master
        restart: unless-stopped
        volumes:
          - /var/run/docker.sock:/var/run/docker.sock

On the containers you want to get started periodically, set the label `de.g3gg0.cron` to either one of
 - 15min
 - hourly
 - daily
 - weekly
 - monthly
 
and that container gets executed with that period.

## Example backup container

This is a real container I use in one of my stacks
    
	  wp-backup:
		build:
		  context: .
		  dockerfile_inline: |
			FROM alpine:3.15
			RUN mkdir -p /aws && apk -Uuv add groff less python3 py3-pip curl mariadb-client && pip3 install --no-cache-dir awscli==1.22.54 && apk --purge -v del py-pip && rm /var/cache/apk/*
		command: >
		  /bin/sh -c "set && 
		  echo Starting FILE backup of $$BACKUP_NAME to $$S3_BUCKET_URL... &&
		  tar -zcvf /tmp/$$BACKUP_NAME.tar.gz /data &&
		  aws s3 cp --storage-class $$S3_STORAGE_CLASS /tmp/$$BACKUP_NAME.tar.gz $$S3_BUCKET_URL &&
		  rm /tmp/$$BACKUP_NAME.tar.gz &&
		  echo 'Backup completed.'"
		environment:
		  - BACKUP_NAME=xxx
		  - AWS_ACCESS_KEY_ID=xxx
		  - AWS_SECRET_ACCESS_KEY=xxx
		  - AWS_DEFAULT_REGION=xxx
		  - S3_BUCKET_URL=s3://xxx
		  - S3_STORAGE_CLASS=STANDARD
		volumes:
		  - wordpress:/data:ro
		labels:
		  de.g3gg0.cron: daily ## execute that container every day
	   





