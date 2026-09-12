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
after the separate network/rebuild confirmation. No OPNsense console setup or
upstream-LAN management rule is part of the process. Gateway remains
WAN-default-deny.

Steps 3-4 are `scripts/terraform/rebuild.ps1`, which runs the same phase
scripts referenced below in order with a confirmation gate before each apply;
see [Gateway configuration](gateway-configuration.md#rebuild-order) for the
full phase list including the attended OPNsense install between them.

## 4. Create Ops, then configure Gateway

Review and apply `scripts/terraform/plan-ops-bootstrap.ps1`. This phase creates
only VMID 1010; all other workloads remain blocked by `gateway_policy_ready`.
From the Ops console, run `playbooks/gateway-tailscale.yml`. It installs the
OPNsense Tailscale plugin through Gateway's seeded API account and configures
the subnet router. Then apply the separate Tailscale Terraform root. The root
owns the tailnet policy and automatic approval for the three Gateway-advertised
VLAN routes. Set `gateway_policy_ready = true` only after that root has
applied successfully.

Gateway does not run a DNS resolver: every service this homelab needs an
internal name for already has a public DNS record, so guests and Gateway
itself both resolve directly through the public resolvers in
`var.dns_servers` / `gateway/baseline.yaml`'s `dns_resolvers`. An earlier
design ran Unbound on Gateway for split-DNS; it was dropped after hitting a
confirmed, still-open upstream OPNsense bug
(<https://github.com/opnsense/core/issues/10723>) where enabled services,
Unbound included, do not reliably survive a reboot.

The same bug affects the Tailscale daemon: after any Gateway reboot or crash,
`tailscaled` comes back disabled and must be started by hand from the
console (`service tailscaled onestart`; plain `service tailscaled start`
refuses because the bug leaves `tailscaled_enable` at `NO` in rc.conf). No
automated recovery exists for this yet.

## 5. Configure Ubuntu guests from Ops

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
