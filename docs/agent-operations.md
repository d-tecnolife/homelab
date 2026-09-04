# Agent identity on Ops

The `agent` account is an unprivileged execution identity for remote agent
sessions. It is separate from the `dtec` administrator, is not a sudoer, and
cannot read the administrator's SOPS age identity. The playbook also installs
Codex from OpenAI's standalone Linux installer into `~/.local/bin`.

## Create or repair the account

From `~/homelab/ansible` on Ops:

```bash
ansible-playbook playbooks/agent-user.yml
```

The playbook installs repository-managed workstation public keys in the
account's `authorized_keys` and prints two repository-specific deploy keys.
Add each under the matching GitHub repository's
**Settings > Deploy keys > Add deploy key**:

- Add the Notes key to `d-tecnolife/notes` with write access disabled.
- Add the Homelab key to `d-tecnolife/homelab` with write access enabled so the
  agent can push reviewed branches. Repository write access does not grant
  deployment or host privileges.

As `agent`, verify GitHub's presented SSH host-key fingerprint, establish the
connection, and clone the context repository:

```bash
ssh -T git@github-notes
ssh -T git@github-homelab
git clone git@github-notes:d-tecnolife/notes.git ~/workspace/notes
git clone git@github-homelab:d-tecnolife/homelab.git ~/workspace/homelab
```

Synchronize and verify the provider-neutral context entry point:

```bash
cd ~/workspace/homelab
bash scripts/context-sync.sh
test -f ../notes/AGENTS.md
```

Authenticate Codex interactively as the agent user:

```bash
codex login
```

Codex authentication is stored under `~/.codex` and must remain outside Git.
The root `AGENTS.md` sends Codex and future compatible agents through the same
Notes context router.

Connect from the workstation:

```bash
ssh agent@10.100.1.10
```

After verifying SSH access, add the same host and user to the Codex desktop
app's SSH connections and select `~/workspace/homelab` as the remote project.
Future agent providers remain separate adapters; their login sessions are
runtime state and must not be committed.

## Operating boundary

The agent may inspect repositories, prepare changes, and run local validation.
It cannot use sudo, decrypt deployment secrets, or SSH to managed VMs by
default. A human administrator reviews the diff and runs privileged Terraform
or Ansible deployment commands. Add narrowly scoped deployment automation only
after its exact commands and approval behavior are defined.
