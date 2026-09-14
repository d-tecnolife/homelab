# Homelab

My home (estate) lab (labyrinth) `labyrinthian-estate`'s infrastructure-as-code.

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

## Validate without deployment

On Ops (or Linux with Terraform installed), install the validation dependencies
in a virtual environment and run the same checks as GitHub Actions:

```bash
python3 -m venv /tmp/homelab-validation
source /tmp/homelab-validation/bin/activate
python -m pip install -r tests/requirements.txt
bash scripts/validate.sh
```

The script initializes locked providers with backend access disabled, checks
formatting and validates both Terraform roots, runs the Python regression and
catalog drift tests, then parses a temporary generated inventory and
syntax-checks every playbook. It does not execute playbooks or decrypt inputs.
`terraform fmt -check` also checks ignored local `.tfvars`; an existing local
formatting failure must be distinguished from changes to tracked code.
