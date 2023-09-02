#!/bin/sh

LOG_DIR=/var/log/llm_worker/
LOG_FILENAME=deployment.log
GCS_DIR=gs://llm_worker/release
LOCAL_CODE_DIR=/var/llm_worker_code
RUNNING_RELEASE_FILE=current_ver.txt
NEW_RELEASE_FILE=new_ver.txt

# created local log directory if it does not exist
if [ ! -d "$LOG_DIR" ]; then
  if ! mkdir -p "$LOG_DIR" ; then
    echo "$(date -u) failed to create log directory"
    LOG_DIR=/tmp
  fi
fi


(
# Install dependencies from apt
apt-get update
apt-get install -yq \
    git build-essential supervisor python python-dev python-pip libffi-dev \
    libssl-dev

# Install logging monitor. The monitor will automatically pickup logs send to
# syslog.
curl -s "https://storage.googleapis.com/signals-agents/logging/google-fluentd-install.sh" | bash
service google-fluentd restart &


REDISHOST=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/redis-host" \
            -H "Metadata-Flavor: Google")
REDISPORT=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/redis-port" \
            -H "Metadata-Flavor: Google")


# created local code directory if it does not exist
if [ ! -d "$LOCAL_CODE_DIR" ]; then
  echo "$(date -u) code directory $LOCAL_CODE_DIR does not exist. Make now..."
  mkdir -p "$LOCAL_CODE_DIR"
fi

# loop to check release file every 2 seconds
while true
do
  sleep 5

  # download GCS release file
  if ! gsutil cp "${GCS_DIR}/${NEW_RELEASE_FILE}" "${LOCAL_CODE_DIR}"; then
    echo "$(date -u) failed to download release file (${GCS_DIR}/${NEW_RELEASE_FILE})"
    continue
  fi

  # Get new release number
  if ! new_release=$(cat "${LOCAL_CODE_DIR}/${NEW_RELEASE_FILE}"); then
    echo "$(date -u) failed to fetch new release version from new release file \
        (${LOCAL_CODE_DIR}/${NEW_RELEASE_FILE})"
    continue
  fi

  # get existing release
  local_release=
  if [ -f "${LOCAL_CODE_DIR}/${RUNNING_RELEASE_FILE}" ] ; then
    if ! local_release=$(cat "${LOCAL_CODE_DIR}/${RUNNING_RELEASE_FILE}"); then
      echo "$(date -u) failed to fetch existing release version from new release file \
          (${LOCAL_CODE_DIR}/${RUNNING_RELEASE_FILE})"
      continue
    fi
  fi

  # Check whether there is new release
  echo "$(date -u) local release: ${local_release}, and remote release: ${new_release}"
  if [ "${local_release}" = "${new_release}" ]; then
    echo "$(date -u) find no new release"
    continue
  else
    echo "$(date -u) find new release; start installation..."
  fi

  # download code file
  new_release_code_zip_file="${GCS_DIR}/${new_release}"
  if gsutil cp "${new_release_code_zip_file}" "${LOCAL_CODE_DIR}/"; then
    echo "$(date -u) downloaded new code file: ${new_release_code_zip_file}"
  else
    echo "$(date -u) failed to download release file matching (${new_release_code_zip_file})"
    continue
  fi

  # unzip code file
  if ! unzip "${LOCAL_CODE_DIR}/${new_release}" "${LOCAL_CODE_DIR}/" ; then
    echo "$(date -u) failed to unzip new release file (${LOCAL_CODE_DIR}/${new_release})"
    continue
  fi

  pip install --upgrade pip virtualenv
  virtualenv /app/env
  /app/env/bin/pip install -r /app/requirements.txt

  # Configure supervisor to run the app.
  cat >/etc/supervisor/conf.d/pythonapp.conf << EOF
  [program:pythonapp]
  directory=/app
  environment=HOME="/home/pythonapp",USER="pythonapp",REDISHOST=$REDISHOST,REDISPORT=$REDISPORT
  command=/app/env/bin/gunicorn main:app --bind 0.0.0:8080
  autostart=true
  autorestart=true
  user=pythonapp
  stdout_logfile=syslog
  stderr_logfile=syslog
EOF
  supervisorctl reread
  supervisorctl update

  echo "$(date -u) complete release new release: ${zipfile_name}"
done


) 2>&1 | tee -a "${LOG_DIR}${LOG_FILENAME}"
