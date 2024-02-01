#!/bin/bash
set -eu

# VARS EVAL.
DEPLOYED_TAG=$(eval echo "$TAG")

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

# We get the status of the latest update.
get-update-status() {
  local TASK_ID="last"
  local ACQUIA_ENV_KEY=''
  get-acquia-key ACQUIA_ENV_KEY

  # Init vars.
  deployment_progress=0
  deployment_completed=0
  while [ "$deployment_progress" -lt 100  ]
    do
      deployment_progress=$(curl -s -u "${ACSF_USER}":"${ACQUIA_ENV_KEY}" -X GET -H 'Content-Type: application/json' \
                   https://www."${ACSF_ENV}"-"${ACSF_SITE}".acsitefactory.com/api/v1/update/"${TASK_ID}"/status | jq -c '.percentage')
      if [[ "$deployment_progress" -lt 100 ]]; then
        echo "Waiting for deployment to finish."
        echo -e "Current percentage progress: ${deployment_progress}% \nTrying again in 5 minutes..."
        sleep 300
      fi
  done
  echo "Deployment progress: ${deployment_progress}% Deployment completed!"
  deployment_completed=1

  # Exporting varibles for Slack messages.
  {
    echo "export ACSF_ENV=$ACSF_ENV"
    echo "export DEPLOYED_TAG=$DEPLOYED_TAG"
    echo "export ACSF_DEPLOYMENT_PROGRESS=$deployment_progress"
    echo "export DEPLOYMENT_COMPLETED=$deployment_completed"
  } >> "$BASH_ENV"
}
get-update-status
