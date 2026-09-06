# Homelab agent entry point

This repository is the desired state for the homelab. Terraform owns Proxmox
resources, Ansible owns guest configuration, and Compose files own application
deployment.

Before reading Notes context, inspect the sibling Notes checkout. When its
worktree is clean and network access is available, sync it with
`git -C ../notes pull --no-rebase`; this fast-forwards when possible and creates
a normal merge commit when committed local history has diverged. Do not use
`scripts/context-sync.sh`. Then read `../notes/AGENTS.md` and follow its router
to exactly the context relevant to the task. If the checkout is missing,
read-only, has uncommitted changes, or cannot be updated, report that condition
and the context's freshness is unverified. Never stash, replace, or overwrite
local work to make a pull succeed.

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
- Follow the sibling Notes root `AGENTS.md` direct-repair workflow for an
  explicitly authorized, localized, reversible deployment. This repository adds
  only the project constraints below; direct repair is incomplete until its
  exact result is reconciled to Terraform, Ansible, or Compose.
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

- The sibling Notes repository's root `AGENTS.md` is the canonical model-routing
  and delegation policy. Read and apply it before choosing a primary or
  specialist. This project adds only the infrastructure-specific constraints
  below; it must not redefine global agent behavior.
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
