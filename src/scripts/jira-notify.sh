# This script can be removed once https://github.com/CircleCI-Public/jira-connect-orb/pull/61
# gets merged.
# : ${CIRCLECI_TOKEN:?"Please provide a CircleCI API token for this orb to work!"} >&2
CIRCLECI_TOKEN=$(eval echo "$CIRCLECI_TOKEN")
JIRA_MANUAL_TAG=$(eval echo "$JIRA_MANUAL_TAG")

echo "Jira Tag: $JIRA_MANUAL_TAG"
if echo "$CIRCLE_REPOSITORY_URL" | grep -q 'github.com'
then
  VCS_TYPE=github
else
  VCS_TYPE=bitbucket
fi

run () {
  verify_api_key
  parse_jira_key_array
    # If you have either an issue key or a service ID
  if [[ -n "${ISSUE_KEYS}" || -n "${JIRA_SERVICE_ID}" ]]; then
    check_workflow_status
    generate_json_payload_"$JIRA_JOB_TYPE"
    post_to_jira
  else
      # If no service is or issue key is found.
    echo "No Jira issue keys found in commit subjects or branch name, skipping."
    echo "No service ID selected. Please add the service_id parameter for JSD deployments."
    exit 0
  fi
}

verify_api_key () {
  URL="https://circleci.com/api/v2/me?circle-token=${CIRCLECI_TOKEN}"
  fetch "${URL}" /tmp/me.json
  jq -e '.login' /tmp/me.json
}

fetch () {
  if [ "${ORB_TEST_ENV}" == "bats-core" ]; then
    return 0
  fi

  URL="$1"
  OFILE="$2"

  if [ -n "${CIRCLECI_TOKEN}" ]; then
      set -- "$@" --user "${CIRCLECI_TOKEN}:"
  fi

  RESP=$(curl -w "%{http_code}" -s "$@" -o "${OFILE}" "${URL}")

  if [[ "$RESP" != "20"* ]]; then
    echo "Curl failed with code ${RESP}. full response below."
    cat "$OFILE"
    exit 1
  fi
}

parse_jira_key_array () {
  ISSUE_KEYS="{["
  if [ -n "${JIRA_ISSUES}" ]; then
    for issue in ${JIRA_ISSUES//,/ }
      do
        ISSUE_KEYS+=\"$issue","\"
      done
    ISSUE_KEYS+="]}"
  fi
  echo "Issue keys: $ISSUE_KEYS"
  if [ -z "$ISSUE_KEYS" ]; then
    # No issue keys found.
    echo "No issue keys found. This build does not contain a match for a Jira Issue. Please add your issue ID to the commit message or within the branch name."
    exit 0
  fi
}

check_workflow_status () {
  URL="https://circleci.com/api/v2/workflow/${CIRCLE_WORKFLOW_ID}"
  fetch "$URL" /tmp/workflow.json
  WORKFLOW_STATUS=$(jq -r '.status' /tmp/workflow.json)
  export WORKFLOW_STATUS=${WORKFLOW_STATUS}
  CIRCLE_PIPELINE_NUMBER=$(jq -r '.pipeline_number' /tmp/workflow.json)
  export CIRCLE_PIPELINE_NUMBER=${CIRCLE_PIPELINE_NUMBER}
  echo "This job is passing, however another job in workflow is ${WORKFLOW_STATUS}"

  if [ "$JIRA_JOB_TYPE" != "deployment" ]; then
      # deployments are special, cause they pass or fail alone.
      # but jobs are stuck togehter, and they must respect status of workflow
      if [[ "$WORKFLOW_STATUS" == "fail"* ]]; then
        export JIRA_BUILD_STATUS="failed"
      fi
  fi
}

generate_json_payload_build () {
  iso_time=$(date '+%Y-%m-%dT%T%z'| sed -e 's/\([0-9][0-9]\)$/:\1/g')
  echo {} | jq \
  --arg time_str "$(date +%s)" \
  --arg lastUpdated "${iso_time}" \
  --arg pipelineNumber "${CIRCLE_PIPELINE_NUMBER}" \
  --arg projectName "${CIRCLE_PROJECT_REPONAME}" \
  --arg state "${JIRA_BUILD_STATUS}" \
  --arg jobName "${CIRCLE_JOB}" \
  --arg buildNumber "${CIRCLE_BUILD_NUM}" \
  --arg url "${CIRCLE_BUILD_URL}" \
  --arg workflowUrl "https://circleci.com/workflow-run/${CIRCLE_WORKFLOW_ID}" \
  --arg commit "${CIRCLE_SHA1}" \
  --arg refUri "${CIRCLE_REPOSITORY_URL}/tree/${CIRCLE_BRANCH}" \
  --arg repositoryUri "${CIRCLE_REPOSITORY_URL}" \
  --arg branchName "${CIRCLE_BRANCH}" \
  --arg workflowId "${CIRCLE_WORKFLOW_ID}" \
  --arg repoName "${CIRCLE_PROJECT_REPONAME}" \
  --arg display "${CIRCLE_PROJECT_REPONAME}"  \
  --arg description "${CIRCLE_PROJECT_REPONAME} #${CIRCLE_BUILD_NUM} ${CIRCLE_JOB}" \
  --argjson issueKeys "${ISSUE_KEYS}" \
  '
  ($time_str | tonumber) as $time_num |
  {
    "builds": [
      {
        "schemaVersion": "1.0",
        "pipelineId": $projectName,
        "buildNumber": $pipelineNumber,
        "updateSequenceNumber": $time_str,
        "displayName": $display,
        "description": $description,
        "url": $workflowUrl,
        "state": $state,
        "lastUpdated": $lastUpdated,
        "issueKeys": $issueKeys
      }
    ]
  }
  ' > /tmp/jira-status.json
}

generate_json_payload_deployment () {
  echo "Update Jira with status: ${JIRA_BUILD_STATUS} for ${CIRCLE_PIPELINE_NUMBER}"
  iso_time=$(date '+%Y-%m-%dT%T%z'| sed -e 's/\([0-9][0-9]\)$/:\1/g')
  echo {} | jq \
  --arg time_str "$(date +%s)" \
  --arg lastUpdated "${iso_time}" \
  --arg state "${JIRA_BUILD_STATUS}" \
  --arg buildNumber "${CIRCLE_BUILD_NUM}" \
  --arg pipelineNumber "${CIRCLE_PIPELINE_NUMBER}" \
  --arg projectName "${CIRCLE_PROJECT_REPONAME}" \
  --arg url "${CIRCLE_BUILD_URL}" \
  --arg commit "${CIRCLE_SHA1}" \
  --arg refUri "${CIRCLE_REPOSITORY_URL}/tree/${CIRCLE_BRANCH}" \
  --arg repositoryUri "${CIRCLE_REPOSITORY_URL}" \
  --arg branchName "${CIRCLE_BRANCH}" \
  --arg workflowId "${CIRCLE_WORKFLOW_ID}" \
  --arg workflowUrl "https://circleci.com/workflow-run/${CIRCLE_WORKFLOW_ID}" \
  --arg repoName "${CIRCLE_PROJECT_REPONAME}" \
  --arg pipelineDisplay "#${CIRCLE_PIPELINE_NUMBER} ${CIRCLE_PROJECT_REPONAME}"  \
  --arg deployDisplay "#${CIRCLE_PIPELINE_NUMBER}  ${CIRCLE_PROJECT_REPONAME} - <<parameters.environment>>"  \
  --arg description "${CIRCLE_PROJECT_REPONAME} #${CIRCLE_PIPELINE_NUMBER} ${CIRCLE_JOB} <<parameters.environment>>" \
  --arg envId "${CIRCLE_WORKFLOW_ID}-${JIRA_ENVIRONMENT}" \
  --arg envName "${JIRA_ENVIRONMENT}" \
  --arg envType "${JIRA_ENVIRONMENT_TYPE}" \
  --arg serviceId "${JIRA_SERVICE_ID}" \
  --argjson issueKeys "${ISSUE_KEYS}" \
  '
  ($time_str | tonumber) as $time_num |
  {
    "deployments": [
      {
        "schemaVersion": "1.0",
        "pipeline": {
          "id": $repoName,
          "displayName": $pipelineDisplay,
          "url": $workflowUrl
        },
        "deploymentSequenceNumber": $pipelineNumber,
        "updateSequenceNumber": $time_str,
        "displayName": $deployDisplay,
        "description": $description,
        "url": $url,
        "state": $state,
        "lastUpdated": $lastUpdated,
        "associations": [
          {
            "associationType": "issueKeys",
            "values": $issueKeys
          },
          {
            "associationType": "serviceIdOrKeys",
            "values": [$serviceId]
          }
        ],
        "environment":{
          "id": $envId,
          "displayName": $envName,
          "type": $envType
        }
      }
    ]
  }
  ' > /tmp/jira-status.json
}


post_to_jira () {
  HTTP_STATUS=$(curl \
  -u "${CIRCLECI_TOKEN}:" \
  -s -w "%{http_code}" -o /tmp/curl_response.txt \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -X POST "https://circleci.com/api/v1.1/project/${VCS_TYPE}/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/jira/${JIRA_JOB_TYPE}" --data @/tmp/jira-status.json)

  echo "Results from Jira: "
  if [ "${HTTP_STATUS}" != "200" ];then
    echo "Error calling Jira, result: ${HTTP_STATUS}" >&2
    jq '.' /tmp/curl_response.txt
    exit 0
  fi

  case "${JIRA_JOB_TYPE}" in
    "build")
      if jq -e '.unknownIssueKeys[0]' /tmp/curl_response.txt > /dev/null; then
        echo "ERROR: unknown issue key"
        jq '.' /tmp/curl_response.txt
        exit 0
      fi
    ;;
    "deployment")
      if jq -e '.unknownAssociations[0]' /tmp/curl_response.txt > /dev/null; then
        echo "ERROR: unknown association"
        jq '.' /tmp/curl_response.txt
        exit 0
      fi
      if jq -e '.rejectedDeployments[0]' /tmp/curl_response.txt > /dev/null; then
        echo "ERROR: Deployment rejected"
        jq '.' /tmp/curl_response.txt
        exit 0
      fi
    ;;
  esac

  # If reached this point, the deployment was a success.
  echo
  jq '.' /tmp/curl_response.txt
  echo
  echo
  echo "Success!"
}

# kick off
if [ "${0#*$ORB_TEST_ENV}" = "$0" ]; then
  # shellcheck disable=SC1091
  # shellcheck source=/dev/null
  source "$JIRA_STATE_PATH"
  run
  rm -f "$JIRA_STATE_PATH"
fi
