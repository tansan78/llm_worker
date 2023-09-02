#!/bin/sh


gcloud services enable  compute.googleapis.com

project_id=sanbeacon-1161
region=us-west1
instance_name=llm-worker-1

case "$1" in
  start)
      gcloud compute instances create "${instance_name}" \
          --image-family=debian-11 \
          --image-project=debian-cloud \
          --machine-type=g1-small \
          --metadata-from-file startup-script-url=startup-script.sh \
          --metadata gcs-bucket=$GCS_BUCKET_NAME,redis-host=$REDISHOST,redis-port=$REDISPORT \
          --zone $ZONE \
          --tags http-server