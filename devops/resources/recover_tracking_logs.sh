#!/bin/bash
set -e

export AWS_DEFAULT_REGION=us-east-1

cd $WORKSPACE/configuration
pip install -r requirements.txt
. util/jenkins/assume-role.sh

assume-role ${ROLE_ARN}

cd $WORKSPACE/private-configuration

echo "Getting instances with missing tracking logs" >&2
INSTANCES=$(aws s3 ls --recursive s3://${BUCKET}/logs/tracking/ | grep -v '\.gz$' | grep -v '0 logs' | sort -n | awk '{print $1"_"$2","$4}')
echo "Finished getting instances" >&2

for INSTANCE in $INSTANCES; do
    # Assume role every time so 1 hour token doesn't expire if the job runs for a long time
    unassume-role
    assume-role ${ROLE_ARN}
    INSTANCE_ID=$(echo "${INSTANCE}" | cut -d / -f 4 | sed 's/-10.*//')
    DATE=$(echo "${INSTANCE}" | cut -d , -f 1)
    IP=$(echo "${INSTANCE}" | cut -d , -f 2 | sed 's/.*-10\./10./' | cut -d / -f 1)
    S3_PREFIX=$(echo "${INSTANCE}" | cut -d , -f 2 | sed 's/\/i-.*$//')
    echo "Looking for snapshot for instance ${INSTANCE_ID} IP:${IP} From:${DATE}" >&2
    SNAPSHOT_ID=$(aws ec2 describe-snapshots --filters Name=tag-key,Values="instance-id" Name=tag-value,Values="${INSTANCE_ID}" --query 'Snapshots[*].SnapshotId' --output text)
    if [ -n "${SNAPSHOT_ID}" ]; then
        IP=$(aws ec2 describe-snapshots --snapshot-id ${SNAPSHOT_ID} --query 'Snapshots[*].Tags[?Key==`hostname`].Value' --output text | sed 's/ip-//' | sed 's/-/./g')
        echo "Recovering tracking logs for instance ${INSTANCE_ID} IP:${IP} From:${DATE}" >&2
        ansible-playbook -u ubuntu -vvv sync_tracking_logs.yml -e "{\"snapshots\": [{\"id\": \"${SNAPSHOT_ID}\", \"s3_path\": \"s3://edx-prod-edx/${S3_PREFIX}/${INSTANCE_ID}-${IP}/\"}]}" -e "security_group_ids=${SG_ID}" -e "subnet_id=${SUBNET_ID}" -e "iam_profile=${IAM_PROFILE}" -clocal
    else
        echo "Unable to find snapshot for instance ${INSTANCE_ID} IP:${IP} From:${DATE}" >&2
    fi
done
