#!/usr/bin/env bash
# Create or update the course EC2 stack in the default VPC and wait until the
# instance answers Session Manager.
#
#   infra/ec2/deploy.sh [--name course-dev] [--type t4g.medium] [--owner me] [--profile course-infra] [--region us-east-1]
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME=course-dev TYPE=t4g.medium OWNER=instructor PROFILE=course-infra REGION=us-east-1 AZ=us-east-1a
while [ $# -gt 0 ]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --type) TYPE="$2"; shift 2 ;;
    --owner) OWNER="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --az) AZ="$2"; shift 2 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done
export PATH="$HOME/.local/bin:$PATH"
A=(--profile "$PROFILE" --region "$REGION")
STACK="$NAME"

echo "==> resolving default VPC subnet in $AZ"
read -r SUBNET VPC < <(aws ec2 describe-subnets "${A[@]}" \
  --filters Name=default-for-az,Values=true "Name=availability-zone,Values=$AZ" \
  --query 'Subnets[0].[SubnetId,VpcId]' --output text)
[ "$SUBNET" != "None" ] || { echo "no default subnet in $AZ" >&2; exit 1; }
echo "    subnet $SUBNET in $VPC"

echo "==> deploying stack $STACK ($TYPE, owner $OWNER)"
aws cloudformation deploy "${A[@]}" \
  --stack-name "$STACK" \
  --template-file "$DIR/template.yaml" \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-fail-on-empty-changeset \
  --parameter-overrides InstanceName="$NAME" InstanceType="$TYPE" Owner="$OWNER" SubnetId="$SUBNET" VpcId="$VPC" \
  --tags Project=course-infra Owner="$OWNER"

ID="$(aws cloudformation describe-stacks "${A[@]}" --stack-name "$STACK" --query 'Stacks[0].Outputs[?OutputKey==`InstanceId`].OutputValue' --output text)"
echo "==> instance $ID, waiting for Session Manager registration"
for i in $(seq 1 40); do
  st="$(aws ssm describe-instance-information "${A[@]}" --filters "Key=InstanceIds,Values=$ID" --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null || true)"
  [ "$st" = "Online" ] && break
  sleep 10
done
[ "$st" = "Online" ] || { echo "instance never came Online in SSM; check the console" >&2; exit 1; }
echo "    SSM Online"

echo "==> waiting for cloud-init (toolchain install) to finish"
for i in $(seq 1 60); do
  out="$("$DIR/run.sh" --profile "$PROFILE" --region "$REGION" --id "$ID" 'cloud-init status 2>/dev/null | head -1' 2>/dev/null || true)"
  case "$out" in *done*|*error*) break ;; esac
  sleep 10
done
echo "    $out"
echo
echo "Instance: $ID"
echo "Shell:    aws ssm start-session --target $ID --region $REGION --profile $PROFILE"
echo "Run cmd:  infra/ec2/run.sh 'uname -a'"
echo "Stop:     aws ec2 stop-instances --instance-ids $ID --region $REGION --profile $PROFILE   (keeps the disk, stops billing for compute)"
echo "Destroy:  infra/ec2/destroy.sh --name $NAME"
