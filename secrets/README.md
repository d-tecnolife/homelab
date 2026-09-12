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
sops ansible/secrets/caddy.sops.env
```

Do not paste the editor contents into logs, issues, commits, or agent chats.
Commit only `caddy.sops.env`.

Edit an encrypted file with:

```bash
SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt" sops ansible/secrets/caddy.sops.env
```

Ansible decrypts the file in memory and writes the destination with restricted
permissions. Tasks handling plaintext use `no_log: true`.

## Gateway Tailscale enrollment

OPNsense Gateway is the sole Tailscale node and advertises the three homelab
VLANs. Store a Tailscale OAuth client (Auth Keys write scope) alongside the
OPNsense API credentials in an encrypted Gateway baseline; `gateway-tailscale.yml`
exchanges it for a short-lived, single-use `tag:gateway` auth key on every run
instead of relying on a long-lived stored key. Do not install Tailscale on
Door or workload VMs: that would create paths which bypass the Gateway's
inter-VLAN enforcement.

The separate `terraform/environments/labyrinthian-estate/tailscale` root uses
a scoped OAuth client from encrypted process environment to own the tailnet
policy and automatically approve Gateway's advertised routes.

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

The same encrypted file stores the scoped Tailscale OAuth client. Manage the
separate tailnet control-plane root with:

```bash
bash scripts/terraform-with-secrets.sh tailscale init
bash scripts/terraform-with-secrets.sh tailscale plan
```

It also stores the seeded `homelab-automation` Gateway API credential (the
same one in `ansible/secrets/gateway.sops.env`), used by the separate
`terraform/environments/labyrinthian-estate/opnsense` root to manage
versioned OPNsense settings (Unbound today) through the live API instead of
the one-time bootstrap ISO render. See that root's own README for why:

```bash
bash scripts/terraform-with-secrets.sh opnsense init
bash scripts/terraform-with-secrets.sh opnsense plan
```

## Compose stacks

Create one encrypted file per stack from its existing example:

```bash
cp compose/vaultwarden/.env.example secrets/compose/vaultwarden.sops.env
sops encrypt --in-place secrets/compose/vaultwarden.sops.env
```

`deploy-compose.yml` decrypts each available stack file in memory and installs
it as `/opt/compose/<stack>/.env` with mode `0640`.

## Vault SSH host-CA token

After initializing HashiCorp Vault, run `vault-ssh-host-ca-bootstrap.yml` once
with a temporary Vault administrator token (`VAULT_TOKEN` env var) to create
the `ssh-host-signer` mount, the `homelab-hosts` signing role, and the
`homelab-ssh-host-signer` policy. That playbook creates the policy only — it
does not mint a token bound to it. As a Vault admin, create the periodic
signing-only token the policy authorizes:

```bash
vault token create -policy=homelab-ssh-host-signer -period=768h -no-default-policy
```

Copy `secrets/vault-ssh-ca.env.example` to `secrets/vault-ssh-ca.sops.env`, set
`VAULT_TOKEN` to that token's value, and encrypt it with SOPS. The
host-certificate playbook decrypts it only on Ops with mode `0600`, installs a
weekly renewal timer that calls `vault-ssh-host-ca.yml --tags renew`, and
extends the token's TTL each run via `auth/token/renew-self` — do not let it
lapse past its period. Do not store Vault root or unseal tokens here.

## Secret classes

- Commit with SOPS encryption: service environment values, API tokens, webhook
  credentials, and deploy-time passwords.
- Keep outside Git: age identities, SSH private keys, GitHub deploy keys, Codex
  login state, recovery codes, and vault-unlocking credentials.
- Keep plaintext in Git: public age recipients, public SSH keys, variable names,
  example values, and non-sensitive configuration.
