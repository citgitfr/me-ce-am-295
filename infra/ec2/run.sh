#!/usr/bin/env bash
# Run a shell command on the course instance through SSM Run Command and print
# its output. Needs no SSH, no open port, and no session-manager-plugin.
#
#   infra/ec2/run.sh 'df -h'                      # on the instance named course-dev
#   infra/ec2/run.sh --name other 'uname -a'
#   infra/ec2/run.sh --id i-0123456789 'ls ~'
#   infra/ec2/run.sh --user ubuntu 'echo $HOME'   # default is root; --user runs it as that login user
set -euo pipefail
NAME=course-dev ID="" PROFILE=course-infra REGION=us-east-1 USER_=root TIMEOUT=600
while [ $# -gt 1 ]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --id) ID="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --user) USER_="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *) break ;;
  esac
done
CMD="${1:?command required}"
export PATH="$HOME/.local/bin:$PATH"
A=(--profile "$PROFILE" --region "$REGION")

if [ -z "$ID" ]; then
  ID="$(aws ec2 describe-instances "${A[@]}" --filters "Name=tag:Name,Values=$NAME" Name=instance-state-name,Values=running \
        --query 'Reservations[0].Instances[0].InstanceId' --output text)"
  [ "$ID" != "None" ] || { echo "no running instance named $NAME" >&2; exit 1; }
fi

if [ "$USER_" != root ]; then
  # base64 keeps multi-line commands and quotes intact through SSM's own shell wrapping
  B64="$(printf '%s' "$CMD" | base64 | tr -d '\n')"
  CMD="echo $B64 | base64 -d | sudo -u $USER_ -H bash -l"
fi
PARAMS="$(python3 -c 'import json,sys;print(json.dumps({"commands":[sys.argv[1]],"executionTimeout":[sys.argv[2]]}))' "$CMD" "$TIMEOUT")"
CID="$(aws ssm send-command "${A[@]}" --instance-ids "$ID" --document-name AWS-RunShellScript \
        --parameters "$PARAMS" --query 'Command.CommandId' --output text)"
for i in $(seq 1 $((TIMEOUT / 2))); do
  st="$(aws ssm get-command-invocation "${A[@]}" --command-id "$CID" --instance-id "$ID" --query Status --output text 2>/dev/null || echo Pending)"
  case "$st" in Pending|InProgress|Delayed) sleep 2 ;; *) break ;; esac
done
aws ssm get-command-invocation "${A[@]}" --command-id "$CID" --instance-id "$ID" --query StandardOutputContent --output text
err="$(aws ssm get-command-invocation "${A[@]}" --command-id "$CID" --instance-id "$ID" --query StandardErrorContent --output text)"
[ -n "$err" ] && [ "$err" != "None" ] && printf '%s\n' "$err" >&2
[ "$st" = "Success" ]
