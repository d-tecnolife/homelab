# Tailscale control plane

This directory is intentionally a separate Terraform root. It owns the
homelab's Tailscale policy and subnet-route approval for Ops; Proxmox VM
state remains in the parent directory.

The policy allows each invited tailnet member to use the VPN to reach the
three homelab VLANs. It does not grant direct access to a workload's
Tailscale address because Ops is the only tailnet node in this design (see
`ansible/playbooks/ops-tailscale.yml`). Tailscale was originally run on
Gateway's `os-tailscale` plugin instead; that was dropped after hitting two
separate, unfixable bugs (OPNsense's own service manager not surviving a
reboot, and the plugin's own config template rendering disabled despite
correctly-persisted settings) with no available upstream fix. Because Ops
(not Gateway) now advertises these routes, traffic reaching them over
Tailscale is **not** filtered by Gateway's firewall the way other traffic
is -- this policy's `grants` is the actual enforcement point for
VPN-originated traffic now, not just route approval.

Create an OAuth client with the Policy File **Write** scope only. Route
approval is declared through this policy's `autoApprovers`; this Terraform root
does not call the device-routes API. Store its values in an encrypted deployment secret and expose them only for Terraform through
`TAILSCALE_OAUTH_CLIENT_ID`, `TAILSCALE_OAUTH_CLIENT_SECRET`, and
`TAILSCALE_TAILNET=-`. Do not put them in a `.tfvars` file or source control.

The first apply replaces the tailnet's complete policy file. Review its plan
carefully and get an explicit confirmation before applying it.
