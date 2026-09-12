# Ansible

Configures Linux guests after Terraform has created their Proxmox resources and
Cloud-Init has assigned their first-boot network configuration.

Follow the [complete environment bootstrap](../docs/environment-bootstrap.md)
for the required execution order.

## Playbooks

Run `../scripts/ops/bootstrap-lab.sh` from the Ops console for the ordered
post-Terraform bootstrap. It renders the inventory, then runs, in order:
`bootstrap-ssh-host-keys.yml` (scans fresh guest SSH host keys into Ops's
`known_hosts` so Ansible has something to verify against), `bootstrap-ops-ssh.yml`
(generates the permanent Ops management key locally and distributes it to
workloads using the temporary Terraform-issued bootstrap key), then
`bootstrap-lab.yml`, an `import_playbook` chain run with the permanent key.

See [`playbooks/bootstrap-lab.yml`](playbooks/bootstrap-lab.yml) for the exact
ordered chain. It configures hostname mappings and network checks, authorizes
the Ops key on Gateway, configures guests, deploys applications and monitoring,
then removes the temporary bootstrap key and console auto-login. The tracked
`.codex/` directory already supplies project agent configuration.

SOPS and the restored age identity must be available before this chain starts:
Gateway key authorization decrypts its input before the later `secrets.yml`
verification. Follow the controller preparation in the environment bootstrap.

Run standalone, outside `bootstrap-lab.yml`:

- `playbooks/nolife-development.yml` bootstraps Nolife as an Ubuntu development
  VM with build tools, Homebrew, Python/pip, Node/npm, Go, Zig, Rustup/Cargo,
  ChezMoi, and a LazyVim starter configuration. It intentionally leaves Docker
  to `playbooks/docker.yml` and only applies ChezMoi when given a dotfiles
  repository URL.
- `playbooks/ops-tailscale.yml` configures Ops as the homelab's Tailscale
  subnet router (installed as an ordinary systemd service, not an OPNsense
  plugin — see `terraform/environments/labyrinthian-estate/tailscale/README.md`
  for why). Part of the Gateway rebuild order in `docs/gateway-configuration.md`,
  not the guest bootstrap chain.
- `playbooks/gateway-firewall-reconcile.yml` defensively reconciles the
  public Git SSH and Ops Gateway administration rules through Gateway's seeded
  API account. It adds missing rules and repairs the administration destination
  and port fields; it is not a full baseline reconciliation.
- `playbooks/vault-ssh-host-ca-bootstrap.yml` and `playbooks/vault-ssh-host-ca.yml`
  establish certificate-based SSH host trust, replacing the ssh-keyscan pinning
  from `bootstrap-ssh-host-keys.yml` host by host as each one is signed. These
  can only run after Vault (the `vault` Compose stack on Apps) has been
  manually initialized/unsealed and Caddy has published `ssh-ca.dscim.dev` —
  both postdate the guest bootstrap chain, so they cannot be folded into it.
  See [Secrets management](../secrets/README.md#vault-ssh-host-ca-token) for
  the exact one-time setup, then the weekly `homelab-vault-ssh-renew.timer`
  keeps every host's certificate current with no further action.

`inventory/hosts.yml` is generated from `topology/workloads.yaml` and ignored
because it is derived output. Generate it without deploying anything (from the
repository root):

```bash
python3 scripts/ops/render-inventory.py --catalog topology/workloads.yaml --output ansible/inventory/hosts.yml
```

The catalog owns ordinary VM definitions and default inventory endpoints for
Ops and Proxmox. Ops retains its separate Terraform bootstrap resource and
variable overrides. Tests check those defaults and Gateway host aliases agree.
For a different environment, pass `--ops-host` / `--proxmox-host` to the renderer;
use an IP or DNS hostname for Proxmox (not its HTTPS URL).
Set `OPS_HOST` / `PROXMOX_HOST` when using `bootstrap-lab.sh` so it regenerates
the same inventory. Match Terraform overrides and review Gateway aliases too.

The repository-local `ansible.cfg` selects inventory automatically when commands run from this directory. It also keeps
Ansible temporary files and SSH control sockets in `/tmp`, so sandboxed runs do
not need write access to `~/.ansible`. The Ops private key remains only on Ops
and must never be committed.

Update hostname mappings on the Linux VMs from Ops:

```bash
ansible-playbook playbooks/hosts-file.yml
```

Install or update the maintenance schedule on Ops:

```bash
ansible-playbook playbooks/maintenance-schedule.yml
systemctl list-timers 'homelab-maintenance-*'
```

Bootstrap the development VM:

```bash
ansible-playbook playbooks/nolife-development.yml
```

To initialize and apply a ChezMoi repository during the same run, supply its
Git URL explicitly. The LazyVim starter is seeded only if `~/.config/nvim` is
absent; add that configuration to the ChezMoi source when you are ready to
manage it as a dotfile.

```bash
ansible-playbook playbooks/nolife-development.yml \
  -e dev_dotfiles_repository=https://github.com/you/dotfiles.git
```

The monthly playbook checks `/var/run/reboot-required`; it does nothing on a
VM that does not require a reboot. Ops schedules its own reboot one minute
after the Ansible run exits. Timers run in the `America/Winnipeg` timezone.

Update a Windows workstation from an elevated PowerShell session:

```powershell
.\scripts\Update-HomelabHosts.ps1
```

Both commands read `ansible/inventory/hosts.yml`. Update the catalog and
regenerate inventory whenever an address changes.

Before deploying Caddy, follow [Secrets management](../secrets/README.md) and
create `secrets/caddy.sops.env`.

Deploy CrowdSec after Caddy so Caddy access logs are available:

```bash
ansible-playbook playbooks/caddy.yml
ansible-playbook playbooks/crowdsec.yml
```

The bouncer enforces community and local decisions on Door. OPNsense Gateway
owns WAN filtering and game-port forwarding. Ops owns Tailscale subnet routing;
the separate Tailscale Terraform root owns its ACL policy.
