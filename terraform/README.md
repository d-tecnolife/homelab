# Terraform

Provisions Proxmox VMs and their cloud-init settings. Guest configuration belongs in Ansible.

The first implementation is [`environments/home`](environments/home), which clones the Ubuntu Resolute template into the `core` VM. It is intentionally direct rather than hidden behind a module; introduce a reusable VM module only when a second VM proves what should be shared.
