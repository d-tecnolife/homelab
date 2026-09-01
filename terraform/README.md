# Terraform

Provisions Proxmox VMs and their cloud-init settings. Guest configuration belongs in Ansible.

<<<<<<< HEAD
[`environments/labyrinthian-estate`](environments/labyrinthian-estate) clones the Ubuntu Resolute template into the VMs hosted by the `labyrinthian-estate` Proxmox node.
=======
The first implementation is [`environments/home`](environments/home), which clones the Ubuntu Resolute template into the `core` VM. It is intentionally direct rather than hidden behind a module; introduce a reusable VM module only when a second VM proves what should be shared.
>>>>>>> 3ac49ecdfc475368d5d3735742b3b2a2e40fc250
