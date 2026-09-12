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

The first phase replaces Gateway VMID 100 only. After its baseline permits
normal VLAN egress, create Ops VMID 1010 as the sole controller exception.
The remaining workloads are gated until Gateway policy and Tailscale routing
have been reconciled. Apply only in a console-attended maintenance window after
an explicit network/rebuild confirmation.

## 3. Build and apply Gateway

On the Proxmox node (or an existing Ops VM), after restoring the age identity,
create the single encrypted Gateway input once with
`scripts/gateway/create-gateway-secret.sh`. Enter one memorable, unique
Gateway console password when asked; it is encrypted with the rest of the
input and is the password used for the one attended OPNsense installation. The
script generates the OPNsense API key and secret without printing them. Build
the bootstrap ISO with
`scripts/gateway/build-opnsense-bootstrap-iso.sh`; when running on Proxmox,
pass `localhost` as its host argument. It renders the WAN, VLAN, firewall, SSH,
and API-account configuration into the installer media.

Run the Gateway-only Terraform plan on the Windows runner and apply it only
after the separate network/rebuild confirmation. The OPNsense install and
configuration import are console-attended; no upstream-LAN management rule is part of the process. Gateway remains
WAN-default-deny.

Steps 3-4 are `scripts/terraform/rebuild.ps1`, which runs the same phase
scripts referenced below in order with a confirmation gate before each apply;
see [Gateway configuration](gateway-configuration.md#rebuild-order) for the
full phase list including the attended OPNsense install between them.

## 4. Create Ops, then configure Gateway

Review and apply `scripts/terraform/plan-ops-bootstrap.ps1`. This phase creates
only VMID 1010, with NICs on all three VLANs (not just Infra) so it can act
as the Tailscale subnet router; all other workloads remain blocked by
`gateway_policy_ready`. Prepare the controller from its Proxmox console before
running any credential-consuming playbook:

```bash
git clone https://github.com/d-tecnolife/homelab.git ~/homelab
# The full distribution supplies collections such as ansible.posix.
sudo apt-get update
sudo apt-get install --yes ansible
cd ~/homelab
python3 scripts/ops/render-inventory.py --catalog topology/workloads.yaml --output ansible/inventory/hosts.yml
cd ansible
ansible-playbook playbooks/bootstrap-ops-ssh.yml --limit ops -c local
ansible-playbook playbooks/secrets.yml -e sops_age_recovery_source=/secure/path/keys.txt
ansible-playbook playbooks/ops-tailscale.yml
```

Restore the backed-up age identity to `/secure/path/keys.txt` (or supply its
actual protected path) before the `secrets.yml` command. Use the original
identity; the playbook installs SOPS/age and verifies encrypted inputs. These
commands are deployment steps, executed only during an authorized rebuild.
`ops-tailscale.yml` installs Tailscale as an ordinary systemd service on Ops
and brings it up as the subnet router. Then apply the separate Tailscale Terraform root. The
root owns the tailnet policy and automatic approval for the three
Ops-advertised VLAN routes. Set `gateway_policy_ready = true` only after
that root has applied successfully.

See [Gateway configuration](gateway-configuration.md#rebuild-order) for the
retired OPNsense Tailscale/Unbound approach and its failure modes. Ops advertises
the VLAN routes directly, so the Tailscale ACL enforces VPN-originated access.
Gateway and guests use public DNS resolvers.

## 5. Configure Ubuntu guests from Ops

Open VMID 1010 through the **Console → xterm.js** serial console in Proxmox.
Use the checkout and restored identity from step 4. Inventory is regenerated
from the catalog by the bootstrap script.
xterm.js is the supported bootstrap console because it can paste text; the
graphical noVNC console remains available as the recovery fallback.

Terraform creates a dedicated, temporary Ops bootstrap SSH key for each fresh
environment. Its public half is installed on every workload VM and its private
half is available only on Ops for the initial key-distribution playbook. The
bootstrap script then switches to the permanent Ops management key and removes
the temporary private key. Terraform state and saved Terraform plans therefore
contain sensitive bootstrap material; keep them local and out of Git.

Authorize Ops on Proxmox first. `bootstrap-proxmox.sh` authorizes the keys
committed under `keys/`, but Ops generates its management key afterwards, so
Proxmox cannot already know it and Ops cannot SSH in to install it. Until this
is done, `monitoring-agents.yml`'s `proxmox_hosts` play fails on "Permission
denied". From the Proxmox console, append Ops' `~/.ssh/id_ed25519.pub` to
`/root/.ssh/authorized_keys`. This is irreducibly manual, like restoring the
age identity.

After the workload Terraform phase is complete, run the ordered configuration
from Ops:

```bash
bash ~/homelab/scripts/ops/bootstrap-lab.sh
```

Before running the command, restore the existing age identity and the required
SOPS-encrypted Compose and Caddy inputs. The playbook deliberately stops rather
than creating replacement credentials that cannot decrypt existing data.

## 6. Certificate-based SSH trust (after Vault is initialized)

This step is separate from `bootstrap-lab.sh` because it depends on things
`bootstrap-lab.sh` itself creates: the `vault` Compose stack on Apps and the
`ssh-ca.dscim.dev` DNS record Caddy publishes. It cannot run any earlier.

1. Manually initialize and unseal Vault (`docker compose exec vault vault
   operator init`, then `vault operator unseal`) — this stays a manual,
   admin-authenticated action, never automated.
2. From Ops, with a temporary Vault administrator token in `VAULT_TOKEN`, run
   `ansible-playbook playbooks/vault-ssh-host-ca-bootstrap.yml` once. It
   creates the SSH secrets engine, the CA, the `homelab-hosts` signing role,
   and a signing-only policy.
3. Create and encrypt the periodic signing token per
   [Secrets management](../secrets/README.md#vault-ssh-host-ca-token).
4. Run `ansible-playbook playbooks/vault-ssh-host-ca.yml`. It signs every
   managed VM's host key, installs the certificate, and — once each host's
   certificate is confirmed working — retires that host's individually pinned
   `known_hosts` entry on Ops in favor of trusting the CA. A weekly timer
   keeps certificates renewed after this; you should not need to touch this
   again.

## Related details

- [Terraform environment](../terraform/environments/labyrinthian-estate/README.md)
- [Ansible playbooks](../ansible/README.md)
