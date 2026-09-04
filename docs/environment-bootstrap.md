# Environment bootstrap

Terraform creates the network and VMs, Cloud-Init makes
Edge route traffic and prepares Ops, Ansible then gives Ops management access
to every VM.

## 1. Prepare Proxmox

**Run on: Proxmox node**

Install Git, clone this repository, then run
both preparation scripts as `root`:

```bash
apt update
apt install -y git
git clone https://github.com/d-tecnolife/homelab.git
cd homelab
./scripts/proxmox/bootstrap-terraform-access.sh
./scripts/proxmox/ubuntu-resolute-cloudinit.sh
```

Save the Terraform token printed by the first script in a password manager.
The second script enables snippets on the `local` datastore and builds Ubuntu
Cloud-Init template `9001`.

## 2. Prepare the Terraform runner

**Run on: Windows workstation**

Open PowerShell as Administrator and enable the Windows SSH agent:

```powershell
Set-Service -Name ssh-agent -StartupType Automatic
Start-Service ssh-agent
```

Return to a normal PowerShell session and load the SSH key that can
authenticate as `root` on Proxmox:

```powershell
ssh-add "$env:USERPROFILE\.ssh\id_ed25519"
ssh-add -l
```

Install the public key on Proxmox using the root password once:

```powershell
Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub" | ssh root@192.168.1.100 "umask 077; mkdir -p /root/.ssh; cat >> /root/.ssh/authorized_keys"
```

Verify that SSH now works without a password:

```powershell
ssh -F NUL -o IdentityFile=none root@192.168.1.100
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

The playbook configures every VM that is currently reachable and skips
powered-off VMs such as k3s. Rerun it after starting an on-demand VM to add
its current host key and the Ops management key. Run:

```bash
ansible-playbook playbooks/bootstrap-ops-ssh.yml
ansible-playbook playbooks/hosts-file.yml
ansible-playbook playbooks/edge-routing.yml
ansible-playbook playbooks/docker.yml
ansible-playbook playbooks/maintenance-schedule.yml
```

The first playbook generates an Ed25519 key on Ops and adds its public key to
every VM. The workstation private key is used through the forwarded agent and
is never copied to Ops. The remaining playbooks maintain VM hostname mappings,
configure Edge routing, and configure Docker.

Create a Cloudflare API token scoped to the `dscim.dev` zone with `Zone:Read`
and `DNS:Edit`. Store it in the ignored Caddy environment file, then deploy
Caddy:

```bash
cp secrets/caddy.env.example secrets/caddy.env
nano secrets/caddy.env
ansible-playbook playbooks/caddy.yml
```

Caddy uses the token only for DNS certificate challenges. This gives private
NetBird services publicly trusted certificates without forwarding ports 80 or
443 through the Rogers router.

Restore each stack's ignored secret files under `compose/<stack>/` on Ops,
then deploy the Compose applications:

```bash
ansible-playbook playbooks/deploy-compose.yml
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
