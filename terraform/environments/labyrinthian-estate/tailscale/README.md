# Tailscale control plane

This directory is intentionally a separate Terraform root. It owns the
homelab's Tailscale policy and Gateway subnet-route approval; Proxmox VM state
remains in the parent directory.

The policy allows each invited tailnet member to use the VPN to reach the three
homelab VLANs. It does not grant direct access to a workload's Tailscale
address because Gateway is the only tailnet node in this design. OPNsense then
enforces the port and VLAN policy.

Create an OAuth client with policy-file and route scopes. Store its values in
an encrypted deployment secret and expose them only for Terraform through
`TAILSCALE_OAUTH_CLIENT_ID`, `TAILSCALE_OAUTH_CLIENT_SECRET`, and
`TAILSCALE_TAILNET=-`. Do not put them in a `.tfvars` file or source control.

The first apply replaces the tailnet's complete policy file. Review its plan
carefully and get an explicit confirmation before applying it.
