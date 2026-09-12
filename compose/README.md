# Compose

These directories are the version-controlled source for Docker stacks. Edit
them in the Homelab checkout on Ops, commit and push, then deploy them with
Ansible. Do not edit the copies under `/opt/compose` on the target VMs.

Real `.env`, `credentials.json`, and `token.json` files are ignored. Store
Compose environment secrets as SOPS-encrypted
`secrets/compose/<stack>.sops.env` files; the deployment playbook decrypts them
only while installing a restricted `.env` on the target VM.

Compose definitions are deployed under `/opt/compose/<stack>`. Persistent
bind-mounted application data is created under `/srv/compose/<stack>` for
consistent backup and recovery.

The `monitoring` stack runs only on the Monitoring VM. The `minecraft` stack
runs only on the Games VM.

## Stacks needing hand-placed files

`wannbot` pulls a pre-built image and needs four files placed on the host at
`/opt/compose/wannbot/` before it will start: `credentials.json`, `token.json`,
`.env`, and `bot_config.py` (see `bot_config.py.example`). They are deliberately
outside the SOPS workflow. Its Compose file declares `create_host_path: false`
for each, so a missing one fails the deploy and names the path rather than
letting Docker create an empty directory in its place.
