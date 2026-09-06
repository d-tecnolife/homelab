# Ansible

Configures Linux guests after Terraform has created their Proxmox resources and
Cloud-Init has assigned their first-boot network configuration.

Follow the [complete environment bootstrap](../docs/environment-bootstrap.md)
for the required execution order.

## Playbooks

- `playbooks/bootstrap-ops-ssh.yml` generates the Ops management key and adds
  its public key to every managed VM without replacing remembered SSH host
  keys.
- `playbooks/secrets.yml` installs SOPS and age on Ops and generates the
  administrator-owned age identity used for deploy-time decryption.
- `playbooks/ops-codex.yml` configures project model routing for `dtec`.
- `playbooks/homelab-health.yml` installs the discretionary JSON health command on Ops.
- `playbooks/monitoring-agents.yml` installs node_exporter and Alloy across
  managed VMs and node_exporter on the Proxmox host.
- `playbooks/monitoring-targets.yml` renders Prometheus file-discovery targets
  from inventory. `playbooks/monitoring-inventory-automation.yml` installs the
  Ops watcher that runs it whenever the private inventory changes.
- `playbooks/hosts-file.yml` maintains short-name and `dscim.dev` mappings in
  `/etc/hosts` on every reachable managed VM using the inventory addresses.
- `playbooks/edge-routing.yml` maintains persistent IPv4 forwarding, the
  CrowdSec nftables sets, and per-source Minecraft connection limits on Edge.
- `playbooks/crowdsec.yml` installs CrowdSec and its nftables bouncer on Edge,
  consumes community decisions, and parses Linux and Caddy logs.
- `playbooks/minecraft-backups.yml` installs the daily Minecraft backup service
  and timer on Games, with five-archive retention and RCON-safe world flushing.
- `playbooks/caddy.yml` installs a Cloudflare-enabled Caddy build on Edge,
  deploys its sites, validates the configuration, and maintains its health
  endpoint and JSON logs.
- `playbooks/docker.yml` installs Docker Engine and Compose on Docker hosts,
  grants the management user Docker access, and creates `/opt/compose`.
- `playbooks/maintenance-schedule.yml` installs Ops systemd timers for daily
  security updates, weekly safe upgrades, and monthly conditional reboots.
- `playbooks/deploy-compose.yml` copies the stacks assigned to each host and
  decrypts any matching `secrets/compose/<stack>.sops.env` file in memory,
  validates, pulls, and applies the stacks with Docker Compose. Each host
  receives only the stacks assigned to it in the playbook.

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
create `secrets/caddy.sops.env`. The playbook temporarily accepts the ignored
plaintext `secrets/caddy.env` to support migration, but new deployments should
use the encrypted file.

Deploy Edge filtering before CrowdSec so the Ansible-owned nftables set exists
before the set-only bouncer starts:

```bash
ansible-playbook playbooks/edge-routing.yml
ansible-playbook playbooks/crowdsec.yml
```

The bouncer enforces community and local decisions in both the input path and
the forwarded Minecraft path. Private LAN and NetBird sources bypass reputation
blocking. Minecraft allows 12 new connections per minute per public source with
a burst of 20; established sessions are not rate-limited.
