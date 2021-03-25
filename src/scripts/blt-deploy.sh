#!/bin/bash
set -eu

# VARS EVAL.
TAG_TO_DEPLOY=$(eval echo "$TAG")

# Determine acquia environment, since acsf user/keys are per env.
get-acquia-key() {
  local -n ACQUIA_KEY="$1"
  if [[ -n ${ACQUIA_KEY_DEV} && -n ${ACQUIA_KEY_TEST} ]]; then
    case "$ACSF_ENV" in
      dev)
          ACQUIA_KEY=${ACQUIA_KEY_DEV};;
      test)
          ACQUIA_KEY=${ACQUIA_KEY_TEST};;
      prod)
          ACQUIA_KEY=${ACQUIA_KEY_PROD};;
      *)
          export ACQUIA_KEY=""
          echo "Provided $ACSF_ENV is not a recognized Env."
          exit 1
          ;;
    esac
  else
    echo "Please set the ACSF User key as an env variable for all your envs. IE: ACQUIA_KEY_DEV and ACQUIA_KEY_TEST".
  fi
}

# Info
echo "Tag to deploy to ${ACSF_ENV}: $TAG_TO_DEPLOY"

deploy-tag-acsf() {
  local ACQUIA_ENV_KEY=''
  get-acquia-key ACQUIA_ENV_KEY

  if [[ -n ${TAG_TO_DEPLOY} && -n ${ACQUIA_ENV_KEY} ]]; then
    echo "Deploying $TAG_TO_DEPLOY to ACSF ${ACSF_ENV}..."
    curl -s -u "${ACSF_USER}":"${ACQUIA_ENV_KEY}" -X POST \
      -H 'Content-Type: application/json' \
      -d '{"scope": "sites", "sites_ref": "tags/'"${TAG_TO_DEPLOY}"'", "sites_type": "'"${DEPLOY_TYPE}"'", "stack_id": 1}' \
      https://www."${ACSF_ENV}"-"${ACSF_SITE}".acsitefactory.com/api/v1/update
    printf "\n"
    ## @to-do: use jq to read response and exit with 1 and error message if 'message' contains Bad Request/Error, etc...
  else
    printf "ERROR: tag and ACQUIA_KEY_[ENV] env variable are required. \nPlease make sure your job is passing the required params and required environment variables are set\n"
  fi
}
deploy-tag-acsf
echo "export ACSF_ENV=$ACSF_ENV" >> $BASH_ENV