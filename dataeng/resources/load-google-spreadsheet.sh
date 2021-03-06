#!/usr/bin/env bash
env

${WORKSPACE}/analytics-configuration/automation/run-automated-task.sh \
 LoadGoogleSpreadsheetsToWarehouseWorkflow --local-scheduler \
 --date $(date +%Y-%m-%d -d "$TO_DATE") \
 --google-credentials $GOOGLE_CREDENTIALS \
 --overwrite
