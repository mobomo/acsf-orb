#!/bin/bash
set -eu

# VARS EVAL.
TAG_TO_DEPLOY=$(eval echo "$TAG")
JIRA_TOKEN=$(eval echo "$JIRA_AUTH_TOKEN")
#JIRA_PROJECT=$(eval echo "$JIRA_PROJECT")

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
CURRENT_TAG=$(get-current-tag)
echo "Current Tag on ${ACSF_ENV}: $CURRENT_TAG"

# Receives jira_project as argument.
# With the current tag, get a list of issues IDs that were committed between current and latest.
# Filtering by Jira Project Key.
get-jira-issues() {
  local jira_project=$1
  local JIRA_ISSUES
  if [ -n "${CURRENT_TAG}" ]; then
    JIRA_ISSUES=$(git log "${CURRENT_TAG}".."${TAG_TO_DEPLOY}" | grep -e "${jira_project}-[0-9]\+" -o | sort -u | tr '\n' ',' | sed '$s/,$/\n/')
    echo "$JIRA_ISSUES"
  else
    echo "We were not able to get current tag deployed to ACSF Env. Please check the 'acsf-' parameters are correctly set."
  fi
}

# Transitions the issues for each project
transition-project-issues() {
  local -a jira_projects
  local -a jira_transitions
  IFS=" " read -r -a jira_projects <<< "${JIRA_PROJECT}"
  IFS=" " read -r -a jira_transitions <<< "${JIRA_TRANS_ID}"
  echo "The Project IDs: " "${jira_projects[@]}"
  echo "The Transition IDs: " "${jira_transitions[@]}"
  # We assume here the project and transition ids will be set in the same order, so we use the keys for each array.
  for key in "${!jira_projects[@]}"; do
    local jira_project=${jira_projects[$key]}
    local jira_trans=${jira_transitions[$key]}

    JIRA_ISSUES=$(get-jira-issues jira_project)
    if [ -n "${JIRA_ISSUES}" ]; then
      echo "Included tickets between ${CURRENT_TAG} and ${TAG_TO_DEPLOY} for Project $jira_project: ${JIRA_ISSUES}"
      echo "export JIRA_ISSUES=$(get-jira-issues jira_project)" >> "$BASH_ENV"
      echo "export JIRA_PROJECT=${jira_project}" >> "$BASH_ENV"
      for issue in ${JIRA_ISSUES//,/ }
        do
          echo "Transitioning to $jira_trans the issue $issue..."
          ## Transition to "Deployed to ${ACSF_ENV}".
          curl \
            -X POST \
            -H "Authorization: Basic ${JIRA_TOKEN}" \
            -H "Content-Type: application/json" \
            --data '{"transition": { "id": "'"${jira_trans}"'" }}' \
            "${JIRA_URL}"/rest/api/2/issue/"$issue"/transitions
        done
    else
      echo "There are no issues to transition."
      echo 'export JIRA_ISSUES="No Tickets"' >> "$BASH_ENV"
    fi
  done
}
transition-project-issues

# Jira API call to transition the issues.
transition-issues() {
  JIRA_ISSUES=$(get-jira-issues)
  if [ -n "${JIRA_ISSUES}" ]; then
    echo "Included tickets between ${CURRENT_TAG} and ${TAG_TO_DEPLOY}: ${JIRA_ISSUES}"
    echo "export JIRA_ISSUES=$(get-jira-issues)" >> "$BASH_ENV"
    echo "export JIRA_PROJECT=${JIRA_PROJECT}" >> "$BASH_ENV"
    for issue in ${JIRA_ISSUES//,/ }
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
    echo 'export JIRA_ISSUES="No Tickets"' >> "$BASH_ENV"
  fi
}
# Use transition-project-issues to test managing different Jira projects.
#transition-issues