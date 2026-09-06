# Environment bootstrap

Terraform creates the network and VMs, Cloud-Init makes
Edge route traffic and prepares Ops, Ansible then gives Ops management access
to every VM.

For replacement hardware or recovery of an existing environment, read
[Rebuild and disaster recovery](disaster-recovery.md) first. In particular,
restore the original age identity rather than generating a new one after
encrypted secrets have been committed.

## 1. Prepare Proxmox

**Run on: Proxmox node**

After installing Proxmox and confirming that its management network and storage
work, run the community [PVE Post Install](https://community-scripts.org/scripts/post-pve-install?id=post-pve-install)
tool as `root`:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/post-pve-install.sh)"
```

Run it interactively and select only the repository and host changes needed for
this installation. It can change the Debian and Proxmox repositories, update the
host, and request a reboot. The subscription-nag modification is optional because
Proxmox package updates can overwrite it.

After it finishes, reboot if prompted and verify the web interface and SSH are
reachable. Confirm the configured repositories are healthy before continuing:

```bash
apt update
pveversion
```

Record the selected options, Proxmox version, and run date in the rebuild notes.

Install Git, clone this repository, then run both repository preparation scripts
as `root`:

```bash
apt update
apt install -y git openssh-client
git clone https://github.com/d-tecnolife/homelab.git
cd homelab
./scripts/proxmox/bootstrap-terraform-access.sh keys/work-computer.pub
./scripts/proxmox/ubuntu-resolute-cloudinit.sh
```

The first script creates both the restricted Linux SSH account and the Proxmox
API identity. Save its Terraform token in a password manager.
The second script enables snippets on the `local` datastore and builds Ubuntu
Cloud-Init template `9001`.

## 2. Prepare the Terraform runner

**Run on: Windows workstation**

Open PowerShell as Administrator and enable the Windows SSH agent:

```powershell
Set-Service -Name ssh-agent -StartupType Automatic
Start-Service ssh-agent
```

Return to a normal PowerShell session and load the same key supplied to the
bootstrap script:

```powershell
ssh-add "$env:USERPROFILE\.ssh\id_ed25519"
ssh-add -l
```

Verify the restricted account and its narrow sudo access:

```powershell
ssh terraform@192.168.1.100 sudo pvesm apiinfo
```

Create an automatically loaded, ignored variables file from the committed
example:

```powershell
cd C:\path\to\homelab\terraform\environments\labyrinthian-estate
Copy-Item terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`. It contains only the Proxmox endpoint, API token, node
name, and VM username. Terraform loads it automatically. Commit and push only
`terraform.tfvars.example`; never commit the populated `terraform.tfvars`.

## 3. Create the environment

**Run on: Windows workstation**

From `terraform/environments/labyrinthian-estate`:

```powershell
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

Terraform creates the VLAN-aware bridge, tagged VM interfaces, Edge, Ops, and
the remaining VMs. Cloud-Init enables IPv4 forwarding on Edge and installs Git
and Ansible on Ops. Wait for Edge to finish before using it as the router:

```powershell
ssh dtec@192.168.1.199 "cloud-init status --wait"
```
Where 192.168.1.199 is edge's IP.

## 4. Add workstation routes

**Run on: Windows workstation as Administrator**

Windows needs routes to the internal networks because the LAN router does
not know them. Open PowerShell as Administrator and use edge's stable
LAN address as the next hop:

```powershell
route -p add 10.100.1.0 mask 255.255.255.0 192.168.1.199
route -p add 10.200.1.0 mask 255.255.255.0 192.168.1.199
```

Disconnect any VPN before connecting to the private subnets; a VPN may route
`10.100.1.0/24` through its virtual interface instead of Edge.

Verify Ops is reachable, then wait for its Cloud-Init setup to finish:

```powershell
Test-NetConnection 10.100.1.10 -Port 22
ssh dtec@10.100.1.10 "cloud-init status --wait"
```

## 5. Bootstrap Ops with agent forwarding

**Begin on: Windows workstation**

Ensure the workstation key is still loaded, then forward its agent to Ops:

```powershell
ssh-add -l
ssh -A dtec@10.100.1.10
```

**Continue on: Ops VM**

Confirm the forwarded identity is visible and clone the repository:

```bash
ssh-add -l
git clone git@github.com:d-tecnolife/homelab.git
cd homelab/ansible
cp inventory/hosts.yml.example inventory/hosts.yml
```

The playbook configures every reachable VM and preserves existing SSH host-key
verification. It never deletes or silently replaces a remembered host key; a
changed key must be verified through the Proxmox console before continuing.
Run:

```bash
ansible-playbook playbooks/bootstrap-ops-ssh.yml
ansible-playbook playbooks/hosts-file.yml
ansible-playbook playbooks/edge-routing.yml
ansible-playbook playbooks/crowdsec.yml
ansible-playbook playbooks/docker.yml
ansible-playbook playbooks/maintenance-schedule.yml
ansible-playbook playbooks/secrets.yml
ansible-playbook playbooks/ops-codex.yml
ansible-playbook playbooks/homelab-health.yml
```

The first playbook generates an Ed25519 key on Ops and adds its public key to
every VM. The workstation private key is used through the forwarded agent and
is never copied to Ops. The remaining playbooks maintain VM hostname mappings,
configure Edge routing, and configure Docker.

Back up the age identity printed by `secrets.yml`, create and commit
`.sops.yaml` from `.sops.yaml.example`, then follow
[Secrets management](../secrets/README.md) to encrypt the Cloudflare API token.
The token should remain scoped to `dscim.dev` with `Zone:Read` and `DNS:Edit`.
Then deploy Caddy:

```bash
ansible-playbook playbooks/caddy.yml
```

Caddy uses the token only for DNS certificate challenges. This gives private
NetBird services publicly trusted certificates without forwarding ports 80 or
443 through the Rogers router.

Create or restore each stack's SOPS-encrypted environment file under
`secrets/compose/` on Ops, then deploy the Compose applications, monitoring
collectors, generated scrape targets, and Minecraft backups:

```bash
ansible-playbook playbooks/deploy-compose.yml
ansible-playbook playbooks/monitoring-agents.yml
ansible-playbook playbooks/monitoring-targets.yml
ansible-playbook playbooks/monitoring-inventory-automation.yml
ansible-playbook playbooks/minecraft-backups.yml
```

## 6. Preserve the Ops public key

**Begin on: Ops VM**

Copy only its public key into the repository:

```bash
cd ~/homelab
mkdir -p keys
cp ~/.ssh/id_ed25519.pub keys/ops-management.pub
git add keys/ops-management.pub
git commit -m "Add Ops management public key"
git push
exit
```

**Continue on: Windows workstation**

Pull the commit containing the Ops public key:

```powershell
cd C:\path\to\homelab
git pull
cd terraform\environments\labyrinthian-estate
```

Review and apply the resulting Terraform update:

```powershell
terraform plan
terraform apply
```

Future workload VM creations and replacements receive both the workstation
and repository-managed public keys during Cloud-Init. Terraform automatically
includes every non-empty repository-root `keys/*.pub` file. After adding another device's
public key, commit it and rerun `bootstrap-ops-ssh.yml` so existing VMs receive
it; private keys remain only on their originating devices.

## 7. Verify management from Ops

**Begin on: Windows workstation**

Reconnect without agent forwarding:

```powershell
ssh dtec@10.100.1.10
```

**Continue on: Ops VM**

Verify the inventory:

```bash
cd ~/homelab/ansible
ansible all -m ping
```

The infrastructure bootstrap is complete when every running VM returns
`SUCCESS`.

## Related details

- [Proxmox access bootstrap](proxmox-bootstrap.md)
- [Terraform environment](../terraform/environments/labyrinthian-estate/README.md)
- [Ansible playbooks](../ansible/README.md)
