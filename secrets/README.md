# Secrets management

SOPS encrypts deploy-time secrets in Git. An age identity stored only on Ops
decrypts them when the administrator runs Ansible. SSH private keys, GitHub
deploy keys, Codex authentication, and the age identity itself never belong in
the repository.

## Bootstrap on Ops

From `~/homelab/ansible`:

```bash
ansible-playbook playbooks/secrets.yml
```

Back up `~/.config/sops/age/keys.txt` to a password manager or offline recovery
store before encrypting anything. Losing every copy of this file makes the
encrypted secrets unrecoverable.

On a replacement Ops VM, do not generate a new identity for existing encrypted
files. Restore the backup with:

```bash
ansible-playbook playbooks/secrets.yml \
  -e sops_age_recovery_source=/secure/path/keys.txt
```

The playbook refuses unsafe key regeneration and tests the restored identity
against every committed SOPS file. See
[Rebuild and disaster recovery](../docs/disaster-recovery.md) for the complete
restore order.

Copy `.sops.yaml.example` to `.sops.yaml`, replace the placeholder with the
public recipient printed by the playbook, and commit `.sops.yaml`. The public
recipient is safe to commit.

## Encrypt the existing Caddy secret

From the repository root on Ops:

```bash
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
cp ansible/secrets/caddy.env ansible/secrets/caddy.sops.env
sops encrypt --in-place ansible/secrets/caddy.sops.env
sops decrypt ansible/secrets/caddy.sops.env
```

The final command is a visual verification. Do not paste its output into logs,
issues, commits, or agent chats. Commit only `caddy.sops.env`, then remove the
ignored plaintext file after a successful Caddy deployment.

Edit an encrypted file with:

```bash
SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt" sops ansible/secrets/caddy.sops.env
```

Ansible decrypts the file in memory and writes the destination with restricted
permissions. Tasks handling plaintext use `no_log: true`.

## Terraform

Copy `secrets/infrastructure.env.example` to
`secrets/infrastructure.sops.env`, replace the example values, and encrypt it
in place before adding it to Git:

```bash
cp secrets/infrastructure.env.example secrets/infrastructure.sops.env
sops encrypt --in-place secrets/infrastructure.sops.env
bash scripts/terraform-with-secrets.sh plan
```

The wrapper uses `sops exec-env`, so Terraform receives `TF_VAR_*` values in
its process environment without a decrypted variables file. It deliberately
accepts only common Terraform actions.

## Compose stacks

Create one encrypted file per stack from its existing example:

```bash
cp compose/vaultwarden/.env.example secrets/compose/vaultwarden.sops.env
sops encrypt --in-place secrets/compose/vaultwarden.sops.env
```

`deploy-compose.yml` decrypts each available stack file in memory and installs
it as `/opt/compose/<stack>/.env` with mode `0640`. Stacks without an encrypted
file retain their existing `.env` during migration.

## Secret classes

- Commit with SOPS encryption: service environment values, API tokens, webhook
  credentials, and deploy-time passwords.
- Keep outside Git: age identities, SSH private keys, GitHub deploy keys, Codex
  login state, recovery codes, and vault-unlocking credentials.
- Keep plaintext in Git: public age recipients, public SSH keys, variable names,
  example values, and non-sensitive configuration.
