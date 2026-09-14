# Homelab

My homelab's infrastructure-as-code.

## Bootstrap

- [Complete environment bootstrap](docs/environment-bootstrap.md)

## Where to change things

- Ordinary VM sizing and addresses, plus inventory endpoints: `config/workloads.yaml`.
- Gateway interfaces, aliases and packet policy: `config/gateway.yaml`.
- Proxmox resources and Ops bootstrap: `terraform/`.
- VPN access policy: `terraform/tailscale/`.
- Guest configuration and its execution order: `ansible/playbooks/bootstrap-lab.yml`.
- Application deployment: `compose/` and `ansible/playbooks/deploy-compose.yml`.
- Encrypted secrets: `secrets/`.
