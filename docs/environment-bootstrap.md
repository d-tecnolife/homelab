# Environment bootstrap

Terraform creates pfSense and the VLAN-attached VMs; Ansible configures the
Ubuntu guests after pfSense has been installed and its firewall policy applied.
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
connection values. Generate a strong local recovery-password hash on Proxmox
without sharing the password or committing either value:

```bash
openssl passwd -6
```

Store the resulting value only as `ops_console_password_hash` in the ignored
`terraform.tfvars`. It permits the `dtec` account to log in through the Ops VM
console; `ssh_pwauth: false` keeps network SSH key-only.

## 2. Review the rebuild

From `terraform/environments/labyrinthian-estate`:

```powershell
terraform init
terraform fmt -check
terraform validate
terraform plan
```

The plan creates pfSense VMID 100 with WAN on `vmbr0` and a tagged `vmbr1`
trunk for VLANs 10, 20, and 30. It creates Ops at `172.16.10.10`, Caddy at
`172.16.30.10`, and the remaining hosts at the addresses in the inventory
example. Apply only in a console-attended maintenance window after an explicit
network/rebuild confirmation.

## 3. Install and configure pfSense

Use the Proxmox console to install the ISO on VMID 100. Assign WAN to `vmbr0`
and the tagged trunk to the LAN interface; create VLAN interfaces 10, 20, and
30. Configure WAN as `192.168.1.2/24` with upstream gateway `192.168.1.1` and
disable WAN blocking of private networks. Apply the exact policy in
[pfSense configuration](pfsense-configuration.md) before starting workloads.

No route or inbound management exception is required on the upstream LAN for
initial setup. Keep WAN default-deny. Use the Proxmox console for VMID 1010
(Ops) as the out-of-band bootstrap path.

## 4. Configure Ubuntu guests from Ops

Open VMID 1010 through the **Console → xterm.js** serial console in Proxmox,
sign in as `dtec` with the local recovery password, clone the repository, copy
the inventory example to the ignored inventory, and run the first playbook
locally. xterm.js is the supported bootstrap console because it can paste text;
the graphical noVNC console remains available as the recovery fallback.

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
