#!/bin/bash
# ================================================================================================
# Script Name: validate.sh
# ================================================================================================
# Purpose:
#   Validates that the Resume Scorer is reachable and Rails is responding.
#   Reads the app URL from Terraform output so it works with or without a
#   custom domain.
# ================================================================================================

set -euo pipefail

APP_URL=$(terraform -chdir=03-ecs output -raw app_url 2>/dev/null)
HEALTH_URL="${APP_URL}/users/sign_in"
MAX_ATTEMPTS=40
SLEEP_SECONDS=15

echo "NOTE: Waiting for ${HEALTH_URL} to return HTTP 200..."

# ------------------------------------------------------------------------------
# Poll Until Healthy
# ------------------------------------------------------------------------------
for ((i=1; i<=MAX_ATTEMPTS; i++)); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 5 \
    "${HEALTH_URL}" 2>/dev/null || echo "000")

  if [ "$STATUS" = "200" ]; then
    echo "NOTE: Resume Scorer is healthy (HTTP 200)."
    echo "NOTE: URL: ${APP_URL}"
    exit 0
  fi

  echo "WARNING: Attempt ${i}/${MAX_ATTEMPTS}: HTTP ${STATUS} — retry in ${SLEEP_SECONDS}s"
  sleep "${SLEEP_SECONDS}"
done

echo "ERROR: Timed out. Check ECS logs in CloudWatch (/ecs/resumescorer)."
exit 1

# ================================================================================================
# End of Script
# ================================================================================================
