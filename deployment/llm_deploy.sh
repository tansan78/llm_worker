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

  echo "$(date -u) complete release new release: ${zipfile_name}"
done


) 2>&1 | tee -a "${LOG_DIR}${LOG_FILENAME}"







<<"COMMENT"

  # check new release
  if [ -f "$local_release_file" ] ; then
    echo "$(date -u) found new release file: ${local_release_file}"
  else
    continue
  fi

  # identify the zip file which has new code
  zipfile_name=$(cat "$local_release_file")
  if [ ! -f "${zipfile_name}" ]; then
    echo "$(date -u) unable to locate zip file: ${zipfile_name}"
    continue
  fi

  # unzip release file
  if ! unzip "${zipfile_name}" -d LOCAL_CODE_DIR ; then
    echo "$(date -u) failed to unzip code release ${zipfile_name}"
    continue
  fi

  # remove release file
  if ! rm -f "${zipfile_name}" ; then
    echo "$(date -u) failed to remove release file ${zipfile_name}"
    continue
  fi


  #
COMMENT