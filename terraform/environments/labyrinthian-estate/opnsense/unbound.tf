# The OPNsense provider is an external control plane against the live
# Gateway API, deliberately separate from the Proxmox VM state in the parent
# directory and from the Tailscale policy in ../tailscale. Credentials are
# supplied only through OPNSENSE_API_KEY/OPNSENSE_API_SECRET (see
# scripts/terraform-with-secrets.sh opnsense <action>); Gateway's address is
# not secret and is already documented throughout this repo.
provider "opnsense" {
  uri            = "https://172.16.10.1"
  allow_insecure = true
}

# Unbound (DNS Resolver) is a versioned OPNsense MVC model
# (OPNsense\Unbound\Unbound, mount //OPNsense/unboundplus, migrations
# 1.0.0-1.0.15). Hand-rendering this section as static XML in
# scripts/gateway/render-opnsense-config.py left it readable but never
# actually running -- confirmed on a from-scratch rebuild: enabled=1 was
# present and round-tripped correctly, but the daemon never started and no
# combination of reboot, "Reload all services", or manual pluginctl
# migration/registration changed that. A section written through the real
# API (as this resource does) gets the model versioning that OPNsense's own
# reconciliation depends on, the same way it already works for Tailscale's
# settings. See ../../../../../docs/gateway-configuration.md and the vault's
# gateway-operations.md for the full diagnostic trail.
#
# This resource is a singleton that must be imported before Terraform can
# manage it -- it configures Unbound's pre-existing settings object, it does
# not create a new one. The import block below does this automatically on
# first apply (Terraform 1.5+).
import {
  to = opnsense_unbound_settings.settings
  id = "unbound_settings"
}

resource "opnsense_unbound_settings" "settings" {
  general = {
    enabled         = false
    port            = 53
    enable_dnssec   = true
    local_zone_type = "transparent"
  }
}
