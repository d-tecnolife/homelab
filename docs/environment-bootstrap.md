# Environment bootstrap

Terraform creates the OPNsense Gateway and VLAN-attached VMs; Ansible configures
Ubuntu guests only after the Gateway baseline and policy have been applied.
For recovery, read [Rebuild and disaster recovery](disaster-recovery.md) first
and restore the original age identity rather than generating a new one.

## 1. Prepare Proxmox and the Terraform runner

On Proxmox, install Git and OpenSSH, clone this repository, then run the
single repository preparation command as `root`:

```bash
apt update
apt install -y git openssh-client
git clone https://github.com/d-tecnolife/homelab.git
cd homelab
bash ./scripts/proxmox/bootstrap-proxmox.sh
```

On the Windows Terraform runner, load the bootstrap key into `ssh-agent`, copy
`terraform.tfvars.example` to ignored `terraform.tfvars`, and enter the Proxmox
connection values. A fresh Ops VM automatically signs `dtec` in through its
Proxmox graphical and serial consoles. This temporary path exists only behind
Proxmox authentication and the Gateway private networks; SSH password
authentication remains disabled. The final Ansible bootstrap removes auto-login
for subsequent boots.

## 2. Review the rebuild

From `terraform/environments/labyrinthian-estate`:

```powershell
terraform init
terraform fmt -check
terraform validate
terraform plan
```

The phase-one plan creates Gateway VMID 100 with WAN on `vmbr0` and a tagged `vmbr1`
trunk for VLANs 10, 20, and 30. It creates Ops at `172.16.10.10`, Door (running Caddy) at
`172.16.30.10`, and the remaining hosts at the addresses in the inventory
example. Apply only in a console-attended maintenance window after an explicit
network/rebuild confirmation.

## 3. Install and configure Gateway

Use the Proxmox console to install the ISO on VMID 100. Assign WAN to `vmbr0`
and the tagged trunk to the LAN interface; create VLAN interfaces 10, 20, and
30. Configure WAN as `192.168.1.2/24` with upstream gateway `192.168.1.1` and
disable WAN blocking of private networks. Apply the exact policy in
[Gateway configuration](gateway-configuration.md) before starting workloads.

No route or inbound management exception is required on the upstream LAN for
initial setup. Keep WAN default-deny. Use the Proxmox console for VMID 1010
(Ops) as the out-of-band bootstrap path.

## 4. Configure Ubuntu guests from Ops

Open VMID 1010 through the **Console → xterm.js** serial console in Proxmox.
The first boot signs `dtec` in automatically; clone the repository, copy the
inventory example to the ignored inventory, and run the first playbook locally.
xterm.js is the supported bootstrap console because it can paste text; the
graphical noVNC console remains available as the recovery fallback.

Terraform creates a dedicated, temporary Ops bootstrap SSH key for each fresh
environment. Its public half is installed on every workload VM and its private
half is available only on Ops for the initial key-distribution playbook. The
bootstrap script then switches to the permanent Ops management key and removes
the temporary private key. Terraform state and saved Terraform plans therefore
contain sensitive bootstrap material; keep them local and out of Git.

```bash
git clone https://github.com/d-tecnolife/homelab.git ~/homelab
cd ~/homelab/ansible
cp inventory/hosts.yml.example inventory/hosts.yml
ansible-playbook -i inventory/hosts.yml playbooks/bootstrap-ops-ssh.yml --limit ops -c local
```

Then run the complete ordered configuration from Ops:

```bash
bash ~/homelab/scripts/ops/bootstrap-lab.sh
```

Before running the command, restore the existing age identity and the required
SOPS-encrypted Compose and Caddy inputs. The playbook deliberately stops rather
than creating replacement credentials that cannot decrypt existing data.

## Related details

- [Proxmox access bootstrap](proxmox-bootstrap.md)
- [Terraform environment](../terraform/environments/labyrinthian-estate/README.md)
- [Ansible playbooks](../ansible/README.md)
