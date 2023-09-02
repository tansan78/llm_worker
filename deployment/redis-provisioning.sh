#!/bin/sh

project_id=sanbeacon-1161
region=us-west1
redis_instance_name="llm-redis"
size=1
version="redis_6_x" # see https://cloud.google.com/sdk/gcloud/reference/redis/instances/create#--redis-version
network="default"

# use service account
# gcloud auth activate-service-account --key-file=./gcp-master-service-account-key.json --project=${project_id}
# use personal account
# gcloud auth --project=${project_id}

gcloud services enable  redis.googleapis.com

case "$1" in
  start)
    echo "$(date -u) start redis instance ${redis_instance_name}"
    if gcloud redis instances create "${redis_instance_name}" \
          --size="${size}" \
          --region="${region}" \
          --network="${network}" \
          --redis-version="${version}" \
          --quiet ; then

      ip=$(gcloud redis instances describe "${redis_instance_name}" \
              --format="get(host)" \
              --region="${region}")
      # auth=$(gcloud redis instances get-auth-string "${redis_instance_name}" \
      #         --region="${region}")
      echo "$(date -u) Redis ${redis_instance_name} IP is ${ip}"
    else
      echo "$(date -u) failed to create redis"
    fi
    ;;
  stop)
    echo "$(date -u) stop redis instance ${redis_instance_name}"
    if gcloud redis instances delete "${redis_instance_name}" --region="${region}" --quiet ; then
      echo "$(date -u) Redis ${redis_instance_name} is stopped"
    else
      echo "$(date -u) failed to stop Redis ${redis_instance_name} is deleted"
    fi
    ;;
  *)
    echo "redis-provisioning start|stop"
esac



<<COM
gcloud services enable \
  compute.googleapis.com \
  redis.googleapis.com \
  cloudresourcemanager.googleapis.com \
  servicenetworking.googleapis.com


private_ip_range_name="internal-gcp-services"
network="default"
ip_range_network_address="10.111.0.0"

gcloud compute addresses create "${private_ip_range_name}" \
  --global \
  --purpose=VPC_PEERING \
  --prefix-length=16 \
  --addresses="${ip_range_network_address}" \
  --description="Peering range for GCP Services" \
  --network="${network}"


gcloud services vpc-peerings connect \
  --service=servicenetworking.googleapis.com \
  --ranges="${private_ip_range_name}" \
  --network="${network}"


region=us-us-west1
redis_instance_name="redis"
size=1
version="redis_6_x" # see https://cloud.google.com/sdk/gcloud/reference/redis/instances/create#--redis-version

gcloud redis instances create "${redis_instance_name}" \
      --size="${size}" \
      --region="${region}" \
      --network="${network}" \
      --redis-version="${version}" \
      --connect-mode=private-service-access \
      --reserved-ip-range="${private_ip_range_name}" \
      --enable-auth \
      -q
COM