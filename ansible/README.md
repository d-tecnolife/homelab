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
--limit ops (generates the permanent Ops management key using the temporary
Terraform-issued bootstrap key), then `bootstrap-lab.yml`, which is a pure
`import_playbook` chain run with the permanent key, in this order:

1. `hosts-file.yml` — short-name and `dscim.dev` mappings in `/etc/hosts` on
   every reachable managed VM, from inventory addresses.
2. `network-preflight.yml` — asserts DNS resolution and public HTTP/HTTPS
   egress before anything else runs; a final assertion, not what establishes
   connectivity (that's the Gateway policy — see `docs/gateway-configuration.md`).
3. `docker.yml` — Docker Engine and Compose plugin on Docker hosts, management
   user added to the `docker` group, `/opt/compose` created.
4. `maintenance-schedule.yml` — installs three Ops systemd timers (daily,
   weekly, monthly-reboot) that each call the merged `maintenance.yml` with
   the matching `--tags`.
5. `secrets.yml` — installs SOPS/age on Ops and generates (or restores) the
   administrator age identity used for deploy-time decryption.
6. `terraform.yml` — installs the pinned Terraform binary on Ops. Needed
   only for `terraform/environments/labyrinthian-estate/opnsense`, the one
   Terraform root that must run from Ops instead of the Windows runner
   (see that root's README); installed unconditionally here so a fresh Ops
   always has it.
7. `ops-codex.yml` — deploys project Codex model-routing config to `dtec`'s
   checkout.
8. `homelab-health.yml` — installs the discretionary JSON health command.
9. `caddy.yml` — Cloudflare-enabled Caddy build on Door, sites, config
   validation, health endpoint and JSON logs.
10. `crowdsec.yml` — CrowdSec and its nftables bouncer on Door, run after
    Caddy so its JSON access logs already exist.
11. `deploy-compose.yml` — copies each host's assigned Compose stacks,
    decrypts any matching `secrets/compose/<stack>.sops.env` in memory,
    pulls and applies with Docker Compose.
12. `playwright.yml` — private Ops→Apps SSH tunnel to the Playwright MCP
    endpoint deployed by `deploy-compose.yml`; must run after it.
13. `monitoring-agents.yml` — node_exporter everywhere plus Grafana Alloy on
    guests.
14. `monitoring-targets.yml` — renders Prometheus file-discovery targets from
    inventory; `monitoring-inventory-automation.yml` installs the Ops watcher
    that reruns it automatically whenever inventory changes.
15. `minecraft-backups.yml` — daily backup service and timer on Games,
    five-archive retention, RCON-safe flush.
16. `lock-bootstrap-console.yml` — removes the temporary bootstrap key and the
    Proxmox-console auto-login. Bootstrap is complete after this step.

Run standalone, outside `bootstrap-lab.yml`:

- `playbooks/nolife-development.yml` bootstraps Nolife as an Ubuntu development
  VM with build tools, Homebrew, Python/pip, Node/npm, Go, Zig, Rustup/Cargo,
  ChezMoi, and a LazyVim starter configuration. It intentionally leaves Docker
  to `playbooks/docker.yml` and only applies ChezMoi when given a dotfiles
  repository URL.
- `playbooks/gateway-tailscale.yml` configures the OPNsense Gateway as the
  Tailscale subnet router through its seeded API account. Part of the Gateway
  rebuild order in `docs/gateway-configuration.md`, not the guest bootstrap
  chain — it runs against `localhost` before most guests exist.
- `playbooks/vault-ssh-host-ca-bootstrap.yml` and `playbooks/vault-ssh-host-ca.yml`
  establish certificate-based SSH host trust, replacing the ssh-keyscan pinning
  from `bootstrap-ssh-host-keys.yml` host by host as each one is signed. These
  can only run after Vault (the `vault` Compose stack on Apps) has been
  manually initialized/unsealed and Caddy has published `ssh-ca.dscim.dev` —
  both postdate the guest bootstrap chain, so they cannot be folded into it.
  See [Secrets management](../secrets/README.md#vault-ssh-host-ca-token) for
  the exact one-time setup, then the weekly `homelab-vault-ssh-renew.timer`
  keeps every host's certificate current with no further action.

`inventory/hosts.yml` is created from `inventory/hosts.yml.example` and ignored
because it contains local network details. The repository-local `ansible.cfg`
selects it automatically when commands run from this directory. It also keeps
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

Both commands read `ansible/inventory/hosts.yml`. Update that inventory first
whenever an address changes.

Before deploying Caddy, follow [Secrets management](../secrets/README.md) and
create `secrets/caddy.sops.env`.

Deploy CrowdSec after Caddy so Caddy access logs are available:

```bash
ansible-playbook playbooks/caddy.yml
ansible-playbook playbooks/crowdsec.yml
```

The bouncer enforces community and local decisions on Door. OPNsense Gateway
owns WAN filtering, game-port forwarding, and Tailscale subnet routing; keep
those rules in the Gateway policy.
