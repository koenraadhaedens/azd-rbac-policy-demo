#!/bin/bash
#
# Post-provision hook: uploads runbook content, publishes it, and links the schedule.
#
# Called by azd after infrastructure provisioning. Uses Az CLI automation extension
# to upload the PowerShell runbook script, publish it, and register the daily schedule.
#

set -euo pipefail

AUTOMATION_ACCOUNT_NAME="${AUTOMATION_ACCOUNT_NAME}"
RESOURCE_GROUP_NAME="${AZURE_RESOURCE_GROUP_NAME}"
RUNBOOK_NAME="Stop-VM-ChangeDisk"
SCHEDULE_NAME="daily-1800-utc"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/Stop-VM-ChangeDisk.ps1"

echo "Installing az automation extension..."
az extension add --name automation --upgrade --yes 2>/dev/null

echo "Uploading runbook content from '${SCRIPT_PATH}'..."
az automation runbook replace-content \
    --automation-account-name "${AUTOMATION_ACCOUNT_NAME}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --name "${RUNBOOK_NAME}" \
    --content "@${SCRIPT_PATH}"

echo "Publishing runbook '${RUNBOOK_NAME}'..."
az automation runbook publish \
    --automation-account-name "${AUTOMATION_ACCOUNT_NAME}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --name "${RUNBOOK_NAME}"

echo "Linking schedule '${SCHEDULE_NAME}' to runbook '${RUNBOOK_NAME}'..."
SCHEDULE_ID=$(az automation schedule show \
    --automation-account-name "${AUTOMATION_ACCOUNT_NAME}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --name "${SCHEDULE_NAME}" \
    --query id -o tsv 2>/dev/null || true)

if [ -n "${SCHEDULE_ID}" ]; then
    JOB_SCHEDULE_GUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)
    az rest --method PUT \
        --uri "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Automation/automationAccounts/${AUTOMATION_ACCOUNT_NAME}/jobSchedules/${JOB_SCHEDULE_GUID}?api-version=2023-11-01" \
        --body "{\"properties\":{\"schedule\":{\"name\":\"${SCHEDULE_NAME}\"},\"runbook\":{\"name\":\"${RUNBOOK_NAME}\"}}}"
    echo "Schedule linked to runbook."
else
    echo "WARNING: Schedule '${SCHEDULE_NAME}' not found. Link manually after verifying schedule exists."
fi

echo "Post-provision complete."

azd env get-values > .env
ENVIRONMENT_NAME="${AZURE_ENV_NAME}"
LOCATION="${AZURE_LOCATION}"
# sending stats to table please comment out if you do not want this

WEBHOOK_URL="https://8116ebc5-9750-4a45-bb68-3623eef692f3.webhook.ne.azure-automation.net/webhooks?token=ZEwDwUSa225CZVgKPQ7ZDDe6K%2f8k9sMl2ou1FJlYpMA%3d"

COMMIT_HASH=$(git rev-parse HEAD)
DEPLOYMENT_DATA=$(cat <<EOF
{
  "Deployment": "azd-nestedhv-dc-rtr",
  "location": "${LOCATION}",
  "environmentName": "${ENVIRONMENT_NAME}",
  "Machine": "${AZUREPS_HOST_ENVIRONMENT:-unknown}",
  "CommitHash": "${COMMIT_HASH}"
}
EOF
)

curl -s -X POST -H "Content-Type: application/json" -d "${DEPLOYMENT_DATA}" "${WEBHOOK_URL}"
echo "Stats Tracked"
