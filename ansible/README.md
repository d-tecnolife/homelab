# Ansible

Configures Linux guests after Terraform has created their Proxmox resources and
Cloud-Init has assigned their first-boot network configuration.

Follow the [complete environment bootstrap](../docs/environment-bootstrap.md)
for the required execution order.

## Playbooks

- `playbooks/bootstrap-ops-ssh.yml` generates the Ops management key and adds
  its public key to every managed VM.
- `playbooks/edge-routing.yml` maintains persistent IPv4 forwarding on Edge.
- `playbooks/caddy.yml` installs Caddy on Edge, validates its configuration,
  and maintains its health endpoint and JSON logs.

`inventory/hosts.yml` is created from `inventory/hosts.yml.example` and ignored
because it contains local network details. The Ops private key remains only on
Ops and must never be committed.
