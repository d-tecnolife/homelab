# Codex operations on Ops

Use the saved Homelab project at `/home/dtec/homelab` on Ops as `dtec`.
Repository work, VM connections, and authorized deployment commands all use
that account. The inventory already selects `dtec` for managed VMs.

The root `AGENTS.md` contains the persistent execution and delegation policy.
It also requires lasting homelab changes to be reproducible through the owning
infrastructure-as-code layer: Terraform for Proxmox resources, Ansible for guest
configuration, and Compose for application deployment. Direct diagnostic or
recovery commands are acceptable when they do not represent desired state; any
persistent live change must be reconciled into the repository before completion.
Project `.codex/config.toml` selects `gpt-5.6-sol` with low reasoning for the
normal primary task. The `architect` role selects Sol with high reasoning, but
is intentionally reserved for genuinely demanding architecture and design
decisions with consequential cross-layer trade-offs. The implementation role
uses `gpt-5.6-terra` with medium reasoning, and the routine role uses
`gpt-5.6-luna` with low reasoning. Exploration, testing, and security review use
Terra with medium reasoning. The primary task should delegate bounded work to
the least expensive suitable specialist and review the result; it should
escalate to the architect role only when its higher-level design judgment is
needed. Explicit task model selections can override the project default;
existing tasks do not switch models retroactively.

The configuration uses the documented [Codex agent settings](https://learn.chatgpt.com/docs/config-file/config-reference)
and [subagent model selection](https://learn.chatgpt.com/docs/agent-configuration/subagents).
The deployment source is `ansible/files/codex/`; keep it identical to `.codex/`
when changing routing. It does not replace the operator's global configuration
or authentication. Codex must trust the project to load project configuration.

After reviewing the diff and explicitly authorizing deployment, run on Ops:

```bash
cd /home/dtec/homelab/ansible
ansible-playbook playbooks/ops-codex.yml
```

Use the existing Codex installation; authenticate interactively with `codex login`
as `dtec` if needed. Authentication and the SOPS age identity remain outside Git.
Open the saved project with an SSH connection using `dtec@10.100.1.10`.
Keep the sibling Notes checkout at `/home/dtec/notes` and follow its context router.

The `dtec` account's privileges do not authorize deployment implicitly. Apply
only named changes explicitly authorized by the user, and obtain separate
confirmation for deletion, rebuilds, storage, or network changes as required by
`AGENTS.md`. Never print decrypted secrets.
