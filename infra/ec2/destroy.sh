#!/usr/bin/env bash
# Delete the course EC2 stack (instance, role, security group). The root volume
# goes with it; copy anything you want to keep out of ~/projects first.
#
#   infra/ec2/destroy.sh [--name course-dev] [--profile course-infra] [--region us-east-1]
set -euo pipefail
NAME=course-dev PROFILE=course-infra REGION=us-east-1
while [ $# -gt 0 ]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done
export PATH="$HOME/.local/bin:$PATH"
A=(--profile "$PROFILE" --region "$REGION")
echo "==> deleting stack $NAME"
aws cloudformation delete-stack "${A[@]}" --stack-name "$NAME"
aws cloudformation wait stack-delete-complete "${A[@]}" --stack-name "$NAME"
echo "    deleted"
