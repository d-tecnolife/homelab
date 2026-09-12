# OPNsense live configuration

This directory is intentionally a separate Terraform root, using
[`browningluke/opnsense`](https://registry.terraform.io/providers/browningluke/opnsense)
to manage OPNsense settings through Gateway's own API after it exists. Proxmox
VM state stays in the parent directory; Tailscale's tailnet policy stays in
`../tailscale`. Apply this root only after Gateway has been created and its
API is reachable — it targets `https://172.16.10.1` directly.

**Run this root from Ops, not the Windows Terraform runner.** Unlike the
parent Proxmox root (reaches Proxmox's WAN-side management IP) and
`../tailscale` (reaches Tailscale's public cloud API), `172.16.10.1` is
Gateway's private Infra-VLAN address — only Ops sits on that VLAN. This
means Terraform needs to be installed on Ops for this one root; it is not
required anywhere else in this repo's Terraform workflow.

## Why a Terraform provider instead of the bootstrap ISO's rendered config

`scripts/gateway/render-opnsense-config.py` hand-builds `config.xml` for the
one-time attended install. That's the right tool for what must exist before
Ops can reach Gateway at all (WAN/VLAN interfaces, seeded admin access, the
anti-lockout rule) — but it is the wrong tool for anything that's a versioned
OPNsense MVC model (identifiable by an `<OPNsense><ModelName>` config path
with its own migration chain), because a hand-written XML section never gets
the model-version stamp OPNsense's own save path adds automatically, and
without it OPNsense's reconciliation does not reliably apply the section even
though the values read back correctly. Confirmed for Unbound (DNS Resolver)
on a from-scratch rebuild; drive that class of setting through the real API
instead, the same way `ansible/playbooks/gateway-tailscale.yml` already does
for the Tailscale plugin.

Add new resources here as more of `render-opnsense-config.py`'s output turns
out to need the same treatment — don't extend the Python renderer to cover
more MVC-versioned sections.

## Secrets

Store `OPNSENSE_API_KEY` and `OPNSENSE_API_SECRET` (the same seeded
`homelab-automation` credential used by `ansible/secrets/gateway.sops.env`)
in the encrypted `secrets/infrastructure.sops.env`, exposed only through
`scripts/terraform-with-secrets.sh opnsense <action>`. Do not put them in a
`.tfvars` file or source control.

## Applying

```bash
bash scripts/terraform-with-secrets.sh opnsense init
bash scripts/terraform-with-secrets.sh opnsense plan
bash scripts/terraform-with-secrets.sh opnsense apply
```

The first apply imports the existing singleton `opnsense_unbound_settings`
resource before changing anything — review that plan like any other
Gateway-affecting change.
