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

## NetBird Edge enrollment

Create a one-off NetBird setup key assigned to the Edge routing-peer group,
then create `ansible/secrets/netbird-edge.sops.env` from its example and
encrypt it. The setup key is used only when Edge is not already connected;
the playbook never writes it to Edge. Run:

```bash
cd ~/homelab/ansible
ansible-playbook playbooks/netbird-edge.yml --limit edge
```

Edge continues to advertise the routed homelab subnets to NetBird clients. The
Vault endpoint itself remains on Edge's management address so it works through
that route and from the home LAN. `caddy.yml` maintains the DNS-only
`ssh-ca.dscim.dev` A record at that management address. Caddy permits NetBird,
`10.0.0.0/8`, and `192.168.0.0/16` sources; it still rejects all other sources.

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

## Vault SSH host-CA token

After initializing HashiCorp Vault and creating its limited host-signing token,
copy `secrets/vault-ssh-ca.env.example` to `secrets/vault-ssh-ca.sops.env`, set
`VAULT_TOKEN`, and encrypt it with SOPS. The host-certificate playbook decrypts
it only on Ops with mode `0600`. Do not store Vault root or unseal tokens here.

## Secret classes

- Commit with SOPS encryption: service environment values, API tokens, webhook
  credentials, and deploy-time passwords.
- Keep outside Git: age identities, SSH private keys, GitHub deploy keys, Codex
  login state, recovery codes, and vault-unlocking credentials.
- Keep plaintext in Git: public age recipients, public SSH keys, variable names,
  example values, and non-sensitive configuration.
