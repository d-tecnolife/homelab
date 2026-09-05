# Homelab agent entry point

This repository is the desired state for the homelab. Terraform owns Proxmox
resources, Ansible owns guest configuration, and Compose files own application
deployment.

Before working, read `../notes/AGENTS.md` and follow its router to exactly the
context relevant to the task. Run `bash scripts/context-sync.sh` first when the
Notes checkout is clean and network access is available. If the Notes checkout
is missing or dirty, report that condition instead of replacing local work.
Read `docs/expected-state.md` before auditing drift, cleaning artifacts, or
correcting unexpected files or behavior.

## Change boundary

- Inspection, explanation, diagnosis, plans, and status requests are read-only.
- Implementation requests may edit and validate this repository but do not
  authorize deployment.
- Run live Ansible playbooks, Terraform apply, restarts, or other infrastructure
  mutations only when the user explicitly asks to deploy or apply the named
  change.
- Require a separate explicit confirmation for deletion, destruction, rebuilds,
  storage changes, and network changes after showing their exact impact.
- Never print, commit, or paste decrypted secrets. The agent account does not
  own the SOPS age identity.

Preserve unrelated changes, prefer the smallest complete implementation, run
the closest validation available, and show the resulting diff before live
deployment.
