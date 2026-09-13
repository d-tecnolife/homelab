# Rebuild and disaster recovery

The homelab is reproducible from Git plus a small set of recovery anchors that
must exist outside the infrastructure being rebuilt.

## Recovery anchors

Keep these outside Proxmox, Ops, Gitea, and the application VMs:

- Access to the public `homelab` repository and a private backup of `notes`.
- The Ops age identity from `~/.config/sops/age/keys.txt`.
- Access to the offsite restic repository in Cloudflare R2 and its
  `RESTIC_PASSWORD` (see [Application data backups](#application-data-backups)).
- Access to GitHub, Cloudflare, the password manager, and their recovery codes.
- At least one administrator SSH private key whose public key is committed
  under `keys/`.
- Terraform state when recovering or moving an existing deployment rather than
  creating a completely new one.

The age identity and application data are the critical non-reproducible items.
API tokens, deploy keys, and Codex authentication can be recreated. Revoke old
credentials when their former host is lost or compromised.

## Fresh rebuild on different hardware

Follow [Environment bootstrap](environment-bootstrap.md) for the executable
sequence: Proxmox preparation, attended Gateway install, Ops creation, identity
restoration and Tailscale setup, then workloads. It is the single rebuild
runbook; the Terraform phase wrappers provide review and confirmation gates.

Recovery-specific requirements:

- A genuinely new environment starts with new Terraform state. Reuse matching
  state when recovering resources that still exist.
- Restore the original age identity before any credential-consuming playbook.
  `secrets.yml -e sops_age_recovery_source=/secure/path/keys.txt` installs the
  tools and verifies the identity, as shown in the bootstrap runbook.
- Restore persistent application data before running `bootstrap-lab.sh`:
  its `deploy-compose.yml` step starts the stacks. See
  [Restore the offsite backup](#restore-the-offsite-backup).
- Restore the operator's repository access and authenticate Codex interactively
  if needed. Git supplies the tracked project configuration.
- Verify routing, DNS, TLS, application health, backups, monitoring, and a test
  alert before declaring recovery complete.

## Existing deployment or control-host recovery

Do not create a new Terraform state for infrastructure that still exists.
Restore the matching state backup or import the existing resources before an
apply. A fresh state is appropriate only when the previous infrastructure no
longer exists and the new machine is a clean rebuild target.

The current repository uses local Terraform state. Until a remote state backend
is introduced, back up the state after every successful apply to storage that
is not hosted by this homelab. State can contain sensitive values and must be
protected like a secret.

## Application data backups

Only Apps holds data a rebuild cannot recreate. Two layers protect it:

| Layer | Contents | Schedule | Location | Retention |
|---|---|---|---|---|
| Offsite | Vaultwarden and job-ops data (SQLite online backups), an Authentik `pg_dump` with its media, and a Vault raft snapshot once `VAULT_SNAPSHOT_TOKEN` is set | Nightly, 02:00 America/Winnipeg (`ansible/playbooks/app-data-backups.yml`) | restic repository in Cloudflare R2 | 7 daily, 4 weekly, 12 monthly |
| Local rollback | The whole Apps VM image | Sundays, 01:30 Proxmox host time (`proxmox_backup_job.apps_weekly`) | Proxmox `local-backup` | 2 images |

Monitoring data, Grafana (its dashboards are provisioned from Git) and every
other VM are reproduced by the rebuild and are not backed up. The local image
shares the Proxmox disk, so only the offsite repository survives losing the
host. `AppDataBackupMissing`, `AppDataBackupFailed` and `AppDataBackupStale`
alert when the offsite backup has never succeeded, last failed, or is older
than 36 hours.

The offsite play configures nothing until `ansible/secrets/backup.sops.env`
exists; create it from `backup.sops.env.example` as described in
[Secrets management](../secrets/README.md#offsite-backup-credentials). To run a
backup immediately instead of waiting for the timer:

```bash
sudo systemctl start homelab-app-backup.service
journalctl -u homelab-app-backup.service -n 30
```

### Restore the offsite backup

On Apps, once `app-data-backups.yml` has installed the credentials, and with
the affected stacks stopped (or before `deploy-compose.yml` first starts them):

```bash
sudo -i
set -a; . /etc/homelab-backup/restic.env; set +a
export AWS_DEFAULT_REGION=auto
restic snapshots --host apps --tag app-data
restic restore latest --host apps --tag app-data --target /root/app-restore
cd /root/app-restore/var/backups/homelab-app-data
```

- **Vaultwarden and job-ops:** replace the contents of
  `/srv/compose/<stack>/data` with the restored `<stack>` directory, then
  `chown -R --reference=/srv/compose/<stack> /srv/compose/<stack>/data`
  before starting the stack.
- **Authentik:** start only `authentik-postgresql`, then load the dump with
  `docker exec -i authentik-postgresql pg_restore --username=authentik
  --dbname=authentik --clean --if-exists < authentik/authentik.pgdump`. Copy
  `authentik/media` and `authentik/custom-templates` into
  `/srv/compose/authentik/` and start the remaining services.
- **Vault:** initialize and unseal the new Vault, then run
  `vault operator raft snapshot restore -force vault/raft.snap` with its root
  token. Vault then needs the original installation's unseal keys.

Delete `/root/app-restore` once the services are verified.

## Recovery test

At least once after major changes, test the process without touching production:

- Clone both repositories into an empty directory.
- Confirm the age backup decrypts all committed SOPS files.
- Run Terraform formatting and validation.
- Run every Ansible playbook with `--syntax-check` and safe playbooks with
  `--check`.
- Confirm application-data backups can be listed and restored to a temporary
  location.

A backup is not a recovery anchor until this test succeeds.
