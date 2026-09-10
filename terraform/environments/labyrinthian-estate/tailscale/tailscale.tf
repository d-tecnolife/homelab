# Tailscale is an external control plane, so it deliberately has its own state
# from the Proxmox environment. Credentials are supplied only through the
# TAILSCALE_OAUTH_CLIENT_ID, TAILSCALE_OAUTH_CLIENT_SECRET, and
# TAILSCALE_TAILNET environment variables.
provider "tailscale" {}

locals {
  gateway_routes = [
    "172.16.10.0/24",
    "172.16.20.0/24",
    "172.16.30.0/24",
  ]

  # Membership of the tailnet is the simple sharing mechanism: invite a person
  # to the tailnet and their own device can use the VPN. OPNsense remains the
  # authoritative port and VLAN firewall for traffic reaching these subnets.
  policy = {
    tagOwners = {
      "tag:gateway" = ["autogroup:admin"]
    }
    grants = [
      {
        src = ["autogroup:member"]
        dst = local.gateway_routes
        ip  = ["*"]
      },
    ]
    autoApprovers = {
      routes = {
        for route in local.gateway_routes : route => ["tag:gateway"]
      }
    }
  }
}

resource "tailscale_acl" "homelab" {
  acl                        = jsonencode(local.policy)
  overwrite_existing_content = true
  reset_acl_on_destroy       = false
}
