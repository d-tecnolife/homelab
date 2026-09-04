# Compose

These directories are the version-controlled source for Docker stacks. Edit
them on Nolife, commit and push, then deploy them from Ops with Ansible. Do not
edit the copies under `/opt/compose` on the target VMs.

Real `.env`, `credentials.json`, and `token.json` files are ignored. Copy
the matching examples, populate secrets outside Git, and place them beside
their Compose file on Ops before deployment.

Compose definitions are deployed under `/opt/compose/<stack>`. Persistent
bind-mounted application data is created under `/srv/compose/<stack>` for
consistent backup and recovery.
