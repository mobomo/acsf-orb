#!/bin/bash
set -eu

#echo "${TAG_TO_DEPLOY}"
#echo "${ACSF_USER}"
#echo "${ACSF_SITE}"
#echo "${ACSF_ENV}"
#echo "${DEPLOY_TYPE}"

get-acquia-key() {
  local -n ACQUIA_KEY="$1"
  if [[ -n ${ACQUIA_KEY_DEV} && -n ${ACQUIA_KEY_TEST} ]]; then
    case "$ACSF_ENV" in
      dev)
          ACQUIA_KEY=${ACQUIA_KEY_DEV};;
      test)
          ACQUIA_KEY=${ACQUIA_KEY_TEST};;
      *)
          ACQUIA_KEY=""
          echo "Provided $ACSF_ENV is not a recognized Env."
          exit 1
          ;;
    esac
  else
    echo "Please set the ACSF User key as an env variable for all your envs. IE: ACQUIA_KEY_DEV and ACQUIA_KEY_TEST".
  fi
}

deploy-tag-acsf() {
  local ACQUIA_KEY=''
  get-acquia-key ACQUIA_KEY
  if [[ -n ${TAG_TO_DEPLOY} && -n ${ACQUIA_KEY} ]]; then
    echo "Deploying ${TAG_TO_DEPLOY} to ACSF ${ACSF_ENV}..."
    curl -s -u "${ACSF_USER}":"${ACQUIA_KEY}" -X POST \
      -H 'Content-Type: application/json' \
      -d '{"scope": "sites", "sites_ref": "tags/'"${TAG_TO_DEPLOY}"'", "sites_type": "'"${DEPLOY_TYPE}"'", "stack_id": 1}' \
      https://www."${ACSF_ENV}"-"${ACSF_SITE}".acsitefactory.com/api/v1/update
  else
    printf "ERROR: tag and ACQUIA_KEY_[ENV] env variable are required. \nPlease make sure your job is passing the required params and required environment variables are set\n"
  fi
}
deploy-tag-acsf
