#!/bin/bash
set -eu

# VARS EVAL.
TAG_TO_DEPLOY=$(eval echo "$TAG")

# Determine acquia environment, since acsf user/keys are per env.
get-acquia-key() {
  local ACQUIA_KEY
  if [[ -n ${ACQUIA_KEY_DEV} && -n ${ACQUIA_KEY_TEST} ]]; then
    case "$ACSF_ENV" in
      dev)
          ACQUIA_KEY=${ACQUIA_KEY_DEV};;
      test)
          ACQUIA_KEY=${ACQUIA_KEY_TEST};;
      prod)
          ACQUIA_KEY=${ACQUIA_KEY_PROD};;
      *)
          ACQUIA_KEY=null
          echo "Provided $ACSF_ENV is not a recognized Env."
          ;;
    esac
    echo "$ACQUIA_KEY"
  else
    echo "Please set the ACSF User key as an env variable for all your envs. IE: ACQUIA_KEY_DEV and ACQUIA_KEY_TEST".
  fi
}

# Get the current tag deployed on acsf env.
get-current-tag() {
  local ACQUIA_KEY
  ACQUIA_KEY=$(get-acquia-key)
  curl -s -X GET https://www."${ACSF_ENV}"-"${ACSF_SITE}".acsitefactory.com/api/v1/vcs?type="sites" \
    -u "${ACSF_USER}":"${ACQUIA_KEY}" | jq -r '.current' | sed 's/tags\///'

}

# Compare the commit SHA the tags points to, to make sure they are different.
compare-tag-commits() {
  CURRENT_TAG=$(get-current-tag)
  echo "Current Tag on ${ACSF_ENV}: $CURRENT_TAG"
  echo "The tag to deploy is $TAG_TO_DEPLOY"

  # Get commits.
  COMMIT_SHA_CURRENT=$(git rev-list -n 1 "$CURRENT_TAG")
  COMMIT_SHA_DEPLOY=$(git rev-list -n 1 "$TAG_TO_DEPLOY")

  echo "$CURRENT_TAG points to commit SHA: $COMMIT_SHA_CURRENT"
  echo "$TAG_TO_DEPLOY points to commit SHA: $COMMIT_SHA_DEPLOY"

  if [ "$COMMIT_SHA_CURRENT" == "$COMMIT_SHA_DEPLOY" ]
  then
    echo "Stopped deployment because the tag to deploy and the one in the destination are the same."
    circleci-agent step halt
  fi
}
compare-tag-commits
