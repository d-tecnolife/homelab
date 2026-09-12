# Tailscale is an external control plane, so it deliberately has its own state
# from the Proxmox environment. Credentials are supplied only through the
# TAILSCALE_OAUTH_CLIENT_ID, TAILSCALE_OAUTH_CLIENT_SECRET, and
# TAILSCALE_TAILNET environment variables.
# The provider sends no scope parameter at all when this is unset, so the
# issued token silently carries whatever the OAuth client happens to have and
# an under-scoped client fails late, as a 403 on the policy write. Naming the
# scope makes a wrong client fail at token exchange instead.
provider "tailscale" {
  scopes = ["policy_file"]
}

locals {
  subnet_routes = [
    "172.16.10.0/24",
    "172.16.20.0/24",
    "172.16.30.0/24",
  ]

  # Ops is the subnet router (ansible/playbooks/ops-tailscale.yml), not
  # Gateway -- OPNsense's os-tailscale plugin hit two separate confirmed
  # bugs (a core service-manager bug and its own broken config template)
  # with no available fix, so Tailscale now runs as an ordinary systemd
  # service on Ops instead. Traffic reaching these subnets over Tailscale is
  # NOT filtered by Gateway's firewall as a result (Ops has direct NICs on
  # all three VLANs for this purpose) -- this ACL policy is the actual
  # enforcement point for VPN-originated traffic now. Membership of the
  # tailnet remains the simple sharing mechanism: invite a person to the
  # tailnet and their own device can use the VPN.
  policy = {
    tagOwners = {
      "tag:ops" = ["autogroup:admin"]
    }
    grants = [
      {
        src = ["autogroup:member"]
        dst = local.subnet_routes
        ip  = ["*"]
      },
    ]
    autoApprovers = {
      routes = {
        for route in local.subnet_routes : route => ["tag:ops"]
      }
    }
  }
}

resource "tailscale_acl" "homelab" {
  acl                        = jsonencode(local.policy)
  overwrite_existing_content = true
  reset_acl_on_destroy       = false
}
