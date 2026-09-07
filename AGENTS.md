# aws-infra

Conventions for AI tools working in this repo. Setup instructions live in
SETUP.md, not here.

- Test bed for the course's AWS compute infra. Two student routes, EC2
  (terminal) and Amazon WorkSpaces (GUI); every infra change is tested on both.
- AWS CLI profile `course-infra`, Region `us-east-1`. Renew with
  `aws login --profile course-infra`.
- Commit messages describe the change only. No author, co-author, or tool
  attribution trailers of any kind.
- `setup/` stays generic: no account IDs or course resources hard-coded.
- The AWS Guidance block below is written by `setup/setup.sh`; change the
  rules in `setup/rules/` or upstream, not here.

<!-- aws-agent-rules:start -->
# AWS Guidance

- Prefer the AWS MCP Server for AWS interactions — it provides sandboxed
  execution, observability, and audit logging. If unavailable, use the
  AWS CLI directly.
- Before starting a task, check whether a relevant AWS skill is available.
  Load the skill with `retrieve_skill` and prefer its guidance over
  general knowledge.
- When uncertain about specific AWS details (API parameters, permissions,
  limits, error codes), verify against documentation rather than guessing.
  State uncertainty explicitly if you cannot confirm.
- When creating infrastructure, prefer infrastructure-as-code (AWS CDK or
  CloudFormation) over direct CLI commands.
- When working with infrastructure, follow AWS Well-Architected Framework
  principles.
- Do not use em dashes in AWS resource names or descriptions. Use
  hyphens instead.

## Secret Safety

- MUST load the `aws-secrets-manager` skill first for any secret,
  credential, API key, token, or password task. MUST NOT call
  `secretsmanager get-secret-value` or `batch-get-secret-value`, and MUST
  NOT hit the Secrets Manager Agent daemon directly. MUST use
  `{{resolve:secretsmanager:secret-id:SecretString:json-key}}` with
  `asm-exec` so the secret resolves at runtime without entering context.
<!-- aws-agent-rules:end -->
