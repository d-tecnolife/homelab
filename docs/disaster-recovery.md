# Rebuild and disaster recovery

The homelab is reproducible from Git plus a small set of recovery anchors that
must exist outside the infrastructure being rebuilt.

## Recovery anchors

Keep these outside Proxmox, Ops, Gitea, and the application VMs:

- Access to the public `homelab` repository and a private backup of `notes`.
- The Ops age identity from `~/.config/sops/age/keys.txt`.
- Backups of irreplaceable application data, especially Vaultwarden.
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
  its `deploy-compose.yml` step starts the stacks. Consult
  [Compose](../compose/README.md) for each stack's storage paths.
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
