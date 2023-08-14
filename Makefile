GCP_PROJECT ?= sanbeacon-1161
GCP_REGION ?= us-west1
GCP_COMPUTE_ZONE ?= us-west1-b
GCS_BUCKET ?= gs://llm_worker

GIT_HASH ?= $(shell git log --format="%h" -n 1)
NEW_RELEASE_FILE=new_ver.txt

gcloud_auth:
	gcloud auth login
	gcloud config set project "${GCP_PROJECT}"
	gcloud config set compute/region "${GCP_REGION}"

release:
	git archive HEAD -o "/tmp/${GIT_HASH}.zip"
	gcloud storage cp "/tmp/${GIT_HASH}.zip" "${GCS_BUCKET}/release/${GIT_HASH}.zip"
	echo "${GIT_HASH}.zip" >> "/tmp/${NEW_RELEASE_FILE}"
	gcloud storage cp "/tmp/${NEW_RELEASE_FILE}" "${GCS_BUCKET}/release/${NEW_RELEASE_FILE}"
