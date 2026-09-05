# Expected state and drift handling

This repository describes the intended homelab state. Agents should compare
the repository, Ops host, and managed systems with this baseline before
correcting unexpected behavior. A difference is evidence to investigate, not
automatic permission to delete or overwrite it.

## Ownership boundaries

- Terraform owns Proxmox resources declared under `terraform/`.
- Ansible owns users, packages, host configuration, and deployed files declared
  under `ansible/`.
- Compose files own application definitions under `compose/`; Ansible performs
  deployment.
- Runtime data and ignored local inputs are not Git-managed desired state.
- `agent@ops` owns `/home/agent/workspace/homelab` and performs public
  repository work as `Ops Agent <ops-agent@dscim.dev>`.
- `dtec@ops` owns `/home/dtec/homelab` and performs private-repository, secret,
  privileged, and deployment operations.
- The `agent` account is not a sudoer and cannot read the age identity.

## Expected repository state

- Tracked source and documentation are reproducible from Git.
- A dirty worktree is not automatically drift. Identify each change, preserve
  unrelated user work, and stage only task-owned files.
- Agent-authored public changes use a `codex/` branch and the Ops Agent Git
  identity. Human commits retain the human identity.
- Local inventory, Terraform values/state, credentials, and decrypted `.env`
  files remain ignored and uncommitted.
- Generated caches, plans, logs, editor backups, and temporary files do not
  belong in Git unless a documented workflow explicitly requires them.

Treat these as unexpected and investigate immediately:

- Private keys, `keys.txt`, credentials, tokens, recovery codes, or plaintext
  secrets anywhere inside the repository.
- A `*.sops.*` file for which `sops filestatus` does not report
  `{"encrypted":true}`.
- Tracked `.env`, `*.tfstate*`, `*.tfvars`, `token.json`, or
  `credentials.json` files that are not explicit sanitized examples.
- Unexplained executables, archives, large binaries, symlinks, duplicate
  configuration trees, or files owned by an unexpected user.
- Conflict markers, interrupted-operation suffixes such as `.pending`, `.tmp`,
  `.orig`, or `.rej`, or an unexpected Git lock file when no Git process runs.

## Expected secrets state

- `/home/dtec/.config/sops/age/keys.txt` is owned by `dtec:dtec`, mode `0600`,
  and never enters Git or the agent checkout.
- `.sops.yaml` contains only public recipient configuration and may be tracked.
- Encrypted files under `secrets/` may be tracked after explicit approval.
- SOPS discovers the age identity automatically when commands run as `dtec`.
- The age identity has a verified off-host recovery copy. Restored identities
  must decrypt every existing encrypted file before deployment.
- Decryption may write to memory, standard output, or an explicitly protected
  temporary destination required by a playbook. Do not leave plaintext copies
  behind.

Useful checks:

```bash
find . -type f \( -name '*.sops.env' -o -name '*.sops.yml' -o -name '*.sops.yaml' -o -name '*.sops.json' \) -print
sops filestatus secrets/compose/monitoring.sops.env
sops decrypt --output /dev/null secrets/compose/monitoring.sops.env
stat -c '%A %U:%G %n' ~/.config/sops/age/keys.txt
```

## Expected execution behavior

- Inspection, validation, planning, and repository edits do not deploy.
- Ansible playbooks, Terraform apply, service restarts, credential rotation,
  firewall changes, and Compose deployment require explicit deployment scope.
- Destruction, deletion, rebuilds, storage changes, and network changes require
  separate confirmation after their impact is shown.
- A validation command must not silently mutate live infrastructure.
- Failed or interrupted operations leave enough evidence for diagnosis, but
  temporary artifacts are removed after their purpose and ownership are
  confirmed.

## Audit sequence

1. Read `AGENTS.md`, this file, and the task-specific runbook.
2. Record identities, current branches, worktree status, ownership, and file
   permissions without printing secret contents.
3. Compare unexpected files with `.gitignore`, Git history, Ansible tasks,
   Terraform configuration/state boundaries, and Compose definitions.
4. Run the closest non-mutating checks: `git diff --check`, Ansible syntax
   checks, Terraform formatting/validation, Compose config validation, and SOPS
   file-status/decryption-to-`/dev/null` checks as applicable.
5. Correct the smallest shared root cause. Preserve unrelated changes and
   remove only artifacts proven to be task-generated and obsolete.
6. Repeat the checks and report preserved anomalies separately from corrected
   drift.

## Automatic correction boundary

Agents may correct repository-owned source, documentation, validation logic,
and confirmed task-created temporary artifacts when implementation is
authorized. Agents must stop and request direction before:

- deleting or overwriting an unknown or user-created file;
- replacing Terraform state, an age identity, a private key, or persistent
  application data;
- changing users, sudoers, SSH access, firewall rules, storage, networking, or
  live services without explicit scope;
- committing newly discovered encrypted secrets to a public repository without
  explicit publication approval;
- resolving drift when Git, Terraform, Ansible, and the live system disagree
  and the authoritative owner is unclear.

When an unexpected condition is safe to observe but unsafe to correct, leave
it unchanged and report the exact path, owner, expected state, observed state,
and required decision.
