GCP_PROJECT ?= sanbeacon-1161
GCP_REGION ?= us-west1
GIT_HASH ?= $(shell git log --format="%h" -n 1)

gcloud_auth:
	gcloud auth login

upload_gcs:
	git archive HEAD -o /tmp/${GIT_HASH}.zip
	gcloud storage cp /tmp/${GIT_HASH}.zip gs://code_deployment/llm_worker/${GIT_HASH}.zip
