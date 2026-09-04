# Rebuild and disaster recovery

The homelab is reproducible from Git plus a small set of recovery anchors that
must exist outside the infrastructure being rebuilt.

## Recovery anchors

Keep these outside Proxmox, Ops, Gitea, and the application VMs:

- Private GitHub copies of the `homelab` and `notes` repositories.
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

1. Install Proxmox and clone `homelab` from GitHub.
2. Run the two scripts in `scripts/proxmox/` to create Terraform access and the
   Cloud-Init template. A new Proxmox API token is expected on a new host.
3. Create a new local `terraform.tfvars` or encrypted
   `secrets/infrastructure.sops.env` using the new endpoint and token.
4. Run Terraform from a trusted workstation to create Edge, Ops, and the
   workload VMs. A genuinely new environment starts with new Terraform state.
5. Clone `homelab` onto Ops and restore the backed-up age identity to a
   temporary local file readable only by the administrator.
6. Restore and verify the identity:

   ```bash
   cd ~/homelab/ansible
   ansible-playbook playbooks/secrets.yml \
     -e sops_age_recovery_source=/secure/path/keys.txt
   ```

   The playbook refuses to generate a replacement key when encrypted repository
   files already exist and verifies that the restored identity decrypts every
   committed SOPS file.
7. Run the remaining bootstrap playbooks, including `agent-user.yml`. Register
   the newly generated GitHub deploy keys and remove the obsolete deploy keys.
8. Restore persistent application data before starting its Compose stack, then
   deploy Caddy and the application stacks through Ansible.
9. Verify routing, DNS, TLS, application health, backups, monitoring, and a test
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
