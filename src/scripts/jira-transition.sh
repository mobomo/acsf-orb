#!/bin/bash
set -eu

# VARS DEBUG.
echo "TAG:: ${TAG}"
echo "CIRCLE_BUILD_NUM:: $CIRCLE_BUILD_NUM"
TAG_TO_DEPLOY=$(eval echo "$TAG")
echo "TAG_TO_DEPLOY:: ${TAG_TO_DEPLOY}"

echo "JIRA_AUTH_TOKEN:: $JIRA_AUTH_TOKEN"
JIRA_TOKEN=$(eval echo "$JIRA_AUTH_TOKEN")
echo "JIRA_TOKEN EVALUATED:: $JIRA_TOKEN"
#echo "${ACSF_USER}"
#echo "${ACSF_SITE}"
#echo "${ACSF_ENV}"
#echo "${JIRA_URL}"
#echo "${JIRA_TRANS_ID}"

# Determine acquia environment, set correct key and get current tag.
get-acquia-key() {
  local ACQUIA_KEY
  if [[ -n ${ACQUIA_KEY_DEV} && -n ${ACQUIA_KEY_TEST} ]]; then
    case "$ACSF_ENV" in
      dev)
          ACQUIA_KEY=${ACQUIA_KEY_DEV};;
      test)
          ACQUIA_KEY=${ACQUIA_KEY_TEST};;
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
CURRENT_TAG=$(get-current-tag)
echo "$CURRENT_TAG"

# With the the current tag, get a list of issues IDs that were committed between current and latest.
get-jira-issues() {
  if [ -n "${CURRENT_TAG}" ]; then
    JIRA_ISSUES=$(git log "${CURRENT_TAG}".."${TAG_TO_DEPLOY}" | grep -e '[A-Z]\+-[0-9]\+' -o | sort -u | tr '\n' ',' | sed '$s/,$/\n/')
    echo "$JIRA_ISSUES"
  else
    echo "We were not able to get current tag deployed to ACSF Env. Please check the 'acsf-' parameters are correctly set."
  fi
}

# Jira API call to transition the issues.
transition-issues() {
  get-jira-issues
  echo "$JIRA_ISSUES"
  if [ -n "${JIRA_ISSUES}" ]; then
    echo "Included tickets between ${CURRENT_TAG} and ${TAG_TO_DEPLOY}: ${JIRA_ISSUES}"
    for issue in ${JIRA_ISSUES}
      do
        echo "Transitioning $issue..."
        ## Transition to "Deployed to ${ACSF_ENV}".
        curl \
          -X POST \
          -H "Authorization: Basic ${JIRA_TOKEN}" \
          -H "Content-Type: application/json" \
          --data '{"transition": { "id": "'"${JIRA_TRANS_ID}"'" }}' \
          "${JIRA_URL}"/rest/api/2/issue/"$issue"/transitions
      done
  else
    echo "There are no issues to transition."
  fi
}
transition-issues
