#!/bin/sh

LOG_DIR=/var/log/llm_worker/
LOG_FILENAME=deployment.log
# GCS_DIR=gs://code_deployment/llm_worker/
# RELEASE_FILENAME_PATTERN=release*.txt
LOCAL_CODE_DIR=/var/llm_worker_code/
RUNNING_RELEASE_FILE=current_ver.txt
NEW_RELEASE_FILE=new_ver.txt

# created local log directory if it does not exist
if [ ! -d "$LOG_DIR" ]; then
  mkdir -p "$LOG_DIR"
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

  echo "$(date -u) complete release new release: ${zipfile_name}"
done



) 2>&1 | tee -a "${LOG_DIR}${LOG_FILENAME}"



<<"COMMENT"
  # Identify local release file
  local_release_file=""
  if local_release_file=$(ls "${LOCAL_CODE_DIR}${RELEASE_FILENAME_PATTERN}") ; then
    echo "$(date -u) found release file: ${local_release_file}"
  else
    echo "$(date -u) failed to identify release file matching (${GCS_DIR}${RELEASE_FILENAME_PATTERN})"
    local_release_file=""
  fi

  # download GCS release file
  if gcs_release_file=$(gsutil ls "${GCS_DIR}${RELEASE_FILENAME_PATTERN}") ; then
    echo "$(date -u) found release file: ${gcs_release_file}"
  else
    echo "$(date -u) failed to identify release file matching (${GCS_DIR}${RELEASE_FILENAME_PATTERN})"
    continue
  fi

  # parse release number
  gcs_release_num=$(basename "$gcs_release_file")
  if [[ -z $local_release_file ]] ; then
    local_release_num=""
  else
    local_release_num=$(parse_release_num $local_release_file)
  fi
  echo "$(date -u) local release: ${local_release_num}, and remote release: ${gcs_release_num}"

  # Check whether there is new release
  if [ "${local_release_num}" = "${gcs_release_num}" ]; then
    echo "$(date -u) find no new release"
    continue
  else
    echo "$(date -u) find new release; start installation..."
  fi

  # get git hash number
  git_hash=$(echo "${gcs_release_num}" | sed 's/[^0-9]*//g')
  if [[ -z $git_hash ]]; then
    echo "$(date -u) failed to identify git hash"
    continue
  fi

  # download code file
  new_release_code_zip_file="${GCS_DIR}${git_hash}.zip"
  if gsutil cp "${new_release_code_zip_file}" "${LOCAL_CODE_DIR}"; then
    echo "$(date -u) downloaded new code file: ${new_release_code_zip_file}"
  else
    echo "$(date -u) failed to download release file matching (${new_release_code_zip_file})"
    continue
  fi

  #
COMMENT