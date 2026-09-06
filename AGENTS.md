# Homelab agent entry point

This repository is the desired state for the homelab. Terraform owns Proxmox
resources, Ansible owns guest configuration, and Compose files own application
deployment.

Before reading Notes context, inspect the sibling Notes checkout. When it is
clean and network access is available, run `bash scripts/context-sync.sh` and
require its fast-forward pull to succeed; then read `../notes/AGENTS.md` and
follow its router to exactly the context relevant to the task. If the checkout
is missing, dirty, read-only, or cannot be updated, report that condition and
the context's freshness is unverified. Never replace or overwrite local work.

Update the routed Homelab IaC context in the sibling Notes repository only when
the `architect` role (`gpt-5.6-sol`, high reasoning) was needed and its outcome
creates a material, reusable architectural or operational decision. Do not
update Notes for routine, localized implementation, configuration, or repair
work. When an update is required, follow the Notes repository's own authoring,
validation, commit, and push rules, and never mix its commit with the Homelab
repository commit.

## Change boundary

- Inspection, explanation, diagnosis, plans, and status requests are read-only.
- Implementation requests may edit and validate this repository but do not
  authorize deployment.
- Run live Ansible playbooks, Terraform apply, restarts, or other infrastructure
  mutations only when the user explicitly asks to deploy or apply the named
  change.
- Require an independent pre-deployment validation pass only when the
  `architect` role (`gpt-5.6-sol`, high reasoning) was needed because the
  proposed deployment is significant or could break dependent systems. Give the
  validator the exact change and scope, require a concise pass/fail result, and
  stop on failure. Routine localized deployments still require the nearest
  local validation, but do not require a separate agent pass.
- Require a separate explicit confirmation for deletion, destruction, rebuilds,
  storage changes, and network changes after showing their exact impact.
- Never print, commit, or paste decrypted secrets. Use secrets only through
  the existing deployment workflow; never expose the SOPS age identity.

Preserve unrelated changes, prefer the smallest complete implementation, run
the closest validation available, and show the resulting diff before live
deployment.

After a requested repository change is complete and its relevant validation
passes, create a task-scoped Conventional Commit and push the current branch.
Never bundle unrelated existing work. If validation fails, ownership is
uncertain, or the push is rejected, report the blocker instead of forcing it.
This is standing authorization to run `git push origin main` for completed,
validated, task-scoped commits in this public repository without requesting
separate approval. It does not authorize releases or other publication,
deployment, destructive operations, force-pushes, or bypassing branch
protection.

## Infrastructure-as-code and reproducibility

- Treat this repository as the authoritative desired state. Implement lasting
  homelab changes as code so a clean environment can reproduce them without
  relying on remembered shell commands or undocumented host state.
- Use Terraform for Proxmox resources and infrastructure lifecycle, Ansible for
  operating-system and guest configuration, and Compose for application stacks.
  Keep ownership in the appropriate layer and avoid managing the same setting
  from multiple layers.
- Decide whether a step belongs in infrastructure as code based on whether it
  represents reusable or persistent desired state. Prefer a reproducible task
  when a change may need to be repeated after rebuild, disaster recovery, host
  replacement, or deployment to another applicable VM.
- One-off inspection, diagnosis, validation, emergency containment, and data
  recovery may use direct commands when encoding them would add no reusable
  value. If a direct change becomes part of the intended steady state, reconcile
  it into Terraform, Ansible, or Compose before considering the work complete.
- Make automation idempotent where practical, parameterize environment-specific
  values, keep secrets in the existing SOPS workflow, and add only the concise
  documentation needed to reproduce and verify the result.
- Validate the nearest infrastructure-as-code layer before proposing deployment:
  format and validate Terraform, syntax-check or check Ansible where meaningful,
  and render or validate Compose configuration without exposing secrets.

## Homelab execution policy

- Work directly from the saved Homelab project on Ops (`/home/dtec/homelab`).
- Use `dtec` for repository inspection, edits, VM connections, and authorized
  deployments.
- Run Ansible commands from `/home/dtec/homelab/ansible` so the repository
  configuration supplies writable temporary and SSH control-socket paths.
- Run `homelab-health` at your discretion when infrastructure implementations
  or fixes would benefit from a baseline or verification. It is not a mandatory
  first step and must not run automatically on every request.
- Consume its compact JSON summary; request selected fields and bounded logs.
  Never dump complete container inspections.
- Default network probes to five seconds. Use longer waits only while installs,
  pulls, backups, or playbooks show progress.
- Batch independent VM checks through one Ansible invocation.
- Stop diagnosis at the first broken dependency, prepare its fix, apply only
  within the deployment authorization above, and verify it once.

## Model routing and delegation

- Default primary: `gpt-5.6-terra`, medium reasoning, for normal investigation,
  coordination, planning within an established design, and review. It is the
  usual task model and should route bounded work to a cheaper suitable role.
- Architecture: `gpt-5.6-sol`, high reasoning (custom `architect` role), is
  deliberately exceptional. Use it only when a task genuinely requires
  demanding architectural or design decisions, such as selecting a durable
  system boundary, resolving consequential trade-offs, or designing a new
  cross-layer approach. Do not use it for routine planning or implementation.
- Implementation: `gpt-5.6-terra`, medium reasoning, for focused Ansible,
  Compose, configuration, tests, and scripts (custom `implementation` role).
- Exploration, testing, and security review: prefer the built-in specialist
  roles with `gpt-5.6-terra`, medium reasoning. If a security task also requires
  genuinely demanding architectural design, escalate that design question to
  the Sol-high architect.
- Cheap routine work: `gpt-5.6-luna`, low reasoning (custom `routine` role), for
  status checks, known deployments, log summaries, simple config changes, and
  other well-understood localized changes. Route these tasks to `routine` by default;
  deployment authorization is required regardless of model.
- Favor token-efficient delegation. Use the least expensive model and reasoning
  level that can reliably complete each bounded task. Delegate independent
  discovery, review, implementation, testing, and routine processes; assign
  clear ownership, preserve in-flight edits, and review results in the primary
  task. Escalate to the Sol-high architect role only when its higher-level
  design judgment is genuinely needed.
- Route deliberately rather than reflexively. Keep a short, sequential task in
  the primary agent when delegation would only add a context handoff. Delegate
  when at least two bounded activities are independent (for example, discovery
  and validation), or when a routine check can run while the primary agent
  plans or edits. Use `routine` for read-only status, known deployments, and
  deterministic validation; use `implementation` for an isolated file set;
  reserve `architect` for a material design decision. Give a delegated agent
  the smallest context that preserves its task, normally no more than the
  relevant files, commands, and acceptance criteria.
- Default to at most two delegated agents. The primary agent owns scope,
  decisions, edits that cross ownership boundaries, deployment authorization,
  and final verification. Do not delegate the same files concurrently or add
  agents merely to repeat a check already covered by a passing preflight.
- For changes that can mutate infrastructure, complete one batched preflight
  before editing or deploying: connectivity and credentials, required
  inventory/targets, service permissions, and the nearest syntax/render check.
  After deployment, run one end-to-end smoke test of the requested outcome;
  repeat checks only when that test exposes a new dependency.
- If the available spawn tool selects models directly instead of named roles,
  pass the model and reasoning explicitly with a bounded context fork; do not
  use a full-history fork when it prevents model overrides.
- Use separate Codex tasks only for independent, long-running projects and only
  when requested. Within one incident or change, use subagents.
