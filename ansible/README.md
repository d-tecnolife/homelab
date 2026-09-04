# Ansible

Configures Linux guests after Terraform has created their Proxmox resources and
Cloud-Init has assigned their first-boot network configuration.

Follow the [complete environment bootstrap](../docs/environment-bootstrap.md)
for the required execution order.

## Playbooks

- `playbooks/bootstrap-ops-ssh.yml` generates the Ops management key and adds
  its public key to every managed VM.
- `playbooks/edge-routing.yml` maintains persistent IPv4 forwarding on Edge.
- `playbooks/caddy.yml` installs a Cloudflare-enabled Caddy build on Edge,
  deploys its sites, validates the configuration, and maintains its health
  endpoint and JSON logs.
- `playbooks/docker.yml` installs Docker Engine and Compose on Ops and Apps,
  grants the management user Docker access, and creates `/opt/compose`.
- `playbooks/deploy-compose.yml` copies the stacks assigned to each host and
  validates, pulls, and applies them with Docker Compose. Apps receives only
  Vaultwarden, Watchtower, WannBot, and Job Ops.

`inventory/hosts.yml` is created from `inventory/hosts.yml.example` and ignored
because it contains local network details. The repository-local `ansible.cfg`
selects it automatically when commands run from this directory. The Ops
private key remains only on Ops and must never be committed.

Before deploying Caddy, copy `secrets/caddy.env.example` to
`secrets/caddy.env` and add a Cloudflare token scoped to `dscim.dev` with
`Zone:Read` and `DNS:Edit`. The populated file is ignored and must not be
committed.
