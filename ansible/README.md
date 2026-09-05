# Ansible

Configures Linux guests after Terraform has created their Proxmox resources and
Cloud-Init has assigned their first-boot network configuration.

Follow the [complete environment bootstrap](../docs/environment-bootstrap.md)
for the required execution order.

## Playbooks

- `playbooks/bootstrap-ops-ssh.yml` generates the Ops management key and adds
  its public key to every managed VM.
- `playbooks/secrets.yml` installs SOPS and age on Ops and generates the
  administrator-owned age identity used for deploy-time decryption. Run it
  before creating `*.sops.*` files; it distinguishes actual SOPS ciphertext
  from plaintext files that merely use the naming convention.
- `playbooks/agent-user.yml` creates the unprivileged agent account, installs
  Codex, and creates repository-specific Notes and Homelab deploy keys.
- `playbooks/monitoring-agents.yml` installs node_exporter and Alloy across
  managed VMs. Proxmox metrics come from its API through pve-exporter, avoiding
  a root SSH dependency on the hypervisor.
- `playbooks/monitoring-targets.yml` renders Prometheus file-discovery targets
  from inventory. `playbooks/monitoring-inventory-automation.yml` installs the
  Ops watcher that runs it whenever the private inventory changes.
- `playbooks/hosts-file.yml` maintains short-name and `dscim.dev` mappings in
  `/etc/hosts` on every reachable managed VM using the inventory addresses.
- `playbooks/edge-routing.yml` maintains persistent IPv4 forwarding on Edge.
- `playbooks/caddy.yml` installs a Cloudflare-enabled Caddy build on Edge,
  deploys its sites, validates the configuration, and maintains its health
  endpoint and JSON logs.
- `playbooks/docker.yml` installs Docker Engine and Compose on Ops, Apps,
  Games, and Monitoring,
  grants the management user Docker access, and creates `/opt/compose`.
- `playbooks/maintenance-schedule.yml` installs Ops systemd timers for daily
  security updates, weekly safe upgrades, and monthly conditional reboots.
- `playbooks/minecraft-backups.yml` installs a daily, RCON-quiesced Minecraft
  archive job on Games. It refuses to write unless `/mnt/game-backups` is a
  separate mounted filesystem and retains exactly the five newest archives.
- `playbooks/deploy-compose.yml` copies the stacks assigned to each host and
  decrypts any matching `secrets/compose/<stack>.sops.env` file in memory,
  validates, pulls, and applies the stacks with Docker Compose. Apps receives
  only Vaultwarden, Watchtower, WannBot, and Job Ops; Games receives only
  Minecraft, and Monitoring receives only the monitoring stack.

`inventory/hosts.yml` is created from `inventory/hosts.yml.example` and ignored
because it contains local network details. The repository-local `ansible.cfg`
selects it automatically when commands run from this directory. The Ops
private key remains only on Ops and must never be committed.

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
