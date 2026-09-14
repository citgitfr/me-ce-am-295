#!/usr/bin/env bash
# Print the handout for one student WorkSpace, plus the details an instructor needs.
#
#   infra/workspaces/handout.sh <workspace-id> --iam-user <username>
#
# Read-only. Defaults: profile course-infra, Region us-west-2.
set -euo pipefail
PROFILE=course-infra; REGION=us-west-2; IAM_USER=""; WS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE=$2; shift 2 ;;
    --region) REGION=$2; shift 2 ;;
    --iam-user) IAM_USER=$2; shift 2 ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    ws-*) WS=$1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$WS" ] || { echo "usage: $0 <workspace-id> [--iam-user <name>] [--profile p] [--region r]" >&2; exit 2; }
aws() { command aws --profile "$PROFILE" --region "$REGION" --output text "$@"; }
lower() { echo "$1" | tr '[:upper:]' '[:lower:]'; }

read -r DIR AD_USER STATE OS COMPUTE < <(aws workspaces describe-workspaces --workspace-ids "$WS" \
  --query 'Workspaces[0].[DirectoryId,UserName,State,WorkspaceProperties.OperatingSystemName,WorkspaceProperties.ComputeTypeName]')
REG=$(aws workspaces describe-workspace-directories --directory-ids "$DIR" --query 'Directories[0].RegistrationCode')
ACCOUNT=$(aws sts get-caller-identity --query Account)

cat <<SHEET
Handout
  AWS account ID     $ACCOUNT
  IAM username       ${IAM_USER:-<fill in>}
  IAM password       <hand over separately>
  WorkSpace ID       $WS

Instructor details
  registration code  $REG
  desktop username   $AD_USER
  desktop            $OS, $COMPUTE, state $STATE
SHEET

if [ -n "$IAM_USER" ]; then
  echo
  if aws iam get-user --user-name "$IAM_USER" --query User.Arn >/dev/null 2>&1; then
    echo "  IAM user $IAM_USER exists, groups: $(aws iam list-groups-for-user --user-name "$IAM_USER" --query 'Groups[].GroupName' | tr '\t' ' ')"
  else
    echo "  ! IAM user $IAM_USER not found"
  fi
  [ "$(lower "$IAM_USER")" = "$(lower "$AD_USER")" ] || echo "  ! desktop username $AD_USER differs from IAM username $IAM_USER; the guide assumes they match"
fi
