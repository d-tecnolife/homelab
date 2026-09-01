# Labyrinthian Estate environment

This environment creates the `core` Docker host and `netbird-router` routing peer by cloning the Ubuntu Resolute cloud-init template built by `scripts/proxmox/ubuntu-resolute-cloudinit.sh`.

## Prerequisites

- Terraform 1.5 or newer
- the template exists on the target Proxmox node (VMID `9001` by default)
- a Proxmox API token with permission to clone and manage VMs
- the SSH public key referenced by `ssh_public_key_file`

## Configure

Keep API credentials out of Terraform files and shell history where possible. The provider reads these environment variables:

```bash
export PROXMOX_VE_ENDPOINT="https://proxmox.example:8006/"
export PROXMOX_VE_API_TOKEN="user@realm!token-id=token-secret"
export PROXMOX_VE_INSECURE="true" # only when the API uses an untrusted certificate
```

Create the local variable file and replace its example values:

```bash
cd terraform/environments/labyrinthian-estate
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` and Terraform state are ignored by Git. The example file contains no credentials.

## Provision VMs

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

After apply, use `terraform output` to find the addresses reported by the QEMU guest agent, then verify SSH access. Guest and service configuration belong in Ansible, not in this Terraform environment or the base image.
