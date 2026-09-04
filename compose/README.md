# Compose

These directories are the version-controlled source for Docker stacks. Edit
them on Dev, commit and push, then deploy them from Ops with Ansible. Do not
edit the copies under `/opt/compose` on the target VMs.

Real `.env`, `credentials.json`, and `token.json` files are ignored. Copy
the matching examples, populate secrets outside Git, and place them beside
their Compose file on Ops before deployment.
