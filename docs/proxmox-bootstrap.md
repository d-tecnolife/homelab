# Proxmox bootstrap

Proxmox installation and the initial Terraform identity remain manual recovery steps. Run the checked-in bootstrap script as `root` on a Proxmox VE node before using `terraform/environments/labyrinthian-estate`:

```bash
./scripts/proxmox/bootstrap-terraform-access.sh
```

The script creates or updates:

- the `terraform@pve` automation user;
- the least-privilege `TerraformVM` role;
- matching user and token ACLs at `/`; and
- the privilege-separated `terraform@pve!provider` API token.

On first creation, Proxmox prints the token secret once. Save it in a password manager. The script does not write the secret to disk and cannot retrieve it on later runs.

Defaults can be overridden when needed:

```bash
TERRAFORM_USER=terraform@pve TOKEN_ID=provider ROLE_ID=TerraformVM \
  ./scripts/proxmox/bootstrap-terraform-access.sh
```

Afterward, configure the Terraform runner without putting the secret in the repository:

```bash
export PROXMOX_VE_ENDPOINT="https://proxmox.example:8006/"
export PROXMOX_VE_API_TOKEN="terraform@pve!provider=token-secret"
export PROXMOX_VE_INSECURE="true"
```

Use `PROXMOX_VE_INSECURE=true` only for an untrusted or self-signed Proxmox certificate.
