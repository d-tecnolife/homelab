# OPNsense Gateway configuration

`gateway` (VMID `100`) is the OPNsense router and firewall. Terraform owns its
Proxmox VM; OPNsense owns the routed interfaces, NAT, DNS overrides, and packet
policy. Guest bootstrapping is intentionally blocked until this policy has been
restored and verified.

Gateway has 4 GiB of RAM. The OPNsense DVD installer clones its live system to
disk and requires at least 3 GiB during that operation; do not reduce this to
the runtime minimum before an installation or rebuild.

## Rebuild order

1. Upload an OPNsense DVD ISO to Proxmox ISO storage and set its exact volume ID
   in the local `gateway_iso_file_id` Terraform variable.
2. Build the bootstrap ISO from the encrypted `gateway.sops.env` input. This is
   an explicit ISO-storage write; review and confirm it before running
   `scripts/gateway/build-opnsense-bootstrap-iso.sh`.
   The root console password is the memorable password entered when creating
   that encrypted input. If it must change before installation, run
   `scripts/gateway/rotate-gateway-root-password.sh`, then rebuild the ISO;
   neither helper prints decrypted credentials.
3. Run `scripts/terraform/migrate-workload-state.ps1 -Apply`. This changes only
   local Terraform addresses, preserving each remote VM and allowing Gateway to
   be planned independently.
4. Run `scripts/terraform/plan-gateway-rebuild.ps1` to create the reviewed
   phase-one plan. It explicitly replaces the appliance, destroying VMID `100`
   and its disk; it never modifies workloads. The wrapper refuses to make a
   plan unless the generated ISO exists in Proxmox storage.
5. The rendered `config.xml` assigns `vtnet0` as WAN and `vtnet1` VLANs `10`,
   `20`, and `30` as LAN, OPT1, and OPT2. It disables WAN private-network
   blocking because the WAN is `192.168.1.2/24` behind `192.168.1.1`.
6. The same rendering process seeds a dedicated API-only `homelab-automation`
   account. Its credential is generated into the encrypted input; no Gateway
   web-GUI access or manual API-key creation is required.
7. Complete the one console-attended OPNsense install using the bootstrap ISO.
   Then run `scripts/terraform/plan-gateway-install-finalize.ps1`, review its
   Gateway-only plan, and apply it after confirmation. It ejects the installer
   media and makes the installed disk first in boot order; do not do either in
   the Proxmox UI.
8. Create Ops (VMID `1010`) as the only controller exception. From its console,
   run the Gateway reconciliation playbook, which installs and configures the
   OPNsense Tailscale plugin, then apply the separate Tailscale Terraform root.
9. Set `gateway_policy_ready = true` only after those steps complete, review
   the workload plan, and apply it.

The bootstrap ISO carries an unencrypted `/conf/config.xml`, so the encrypted
baseline is decrypted only into a protected temporary build location and
removed after the ISO is prepared. The OPNsense DVD installer is interactive:
it requires a console-attended installation and configuration-import step.
The ISO removes policy entry and credential creation from that step; it does
not make the upstream installer unattended. Do not place a decrypted
configuration in Git or Terraform state.

## Baseline interfaces

| OPNsense interface | Proxmox NIC | Address | Purpose |
| --- | --- | --- | --- |
| WAN | `vtnet0` on `vmbr0` | `192.168.1.2/24`, gateway `192.168.1.1` | upstream network |
| LAN | OPNsense `vlan0` (VLAN 10 on `vtnet1` / tagged `vmbr1`) | `172.16.10.1/24` | Infra |
| OPT1 | OPNsense `vlan1` (VLAN 20 on `vtnet1` / tagged `vmbr1`) | `172.16.20.1/24` | Internal |
| OPT2 | OPNsense `vlan2` (VLAN 30 on `vtnet1` / tagged `vmbr1`) | `172.16.30.1/24` | DMZ |

Unbound serves catalog-derived `dscim.dev` host overrides to every VLAN guest;
Terraform therefore configures each guest to use its VLAN Gateway as DNS. Do
not enable NAT reflection. Outbound NAT translates the three VLAN networks to
WAN.

OPNsense's automatic LAN anti-lockout rule is disabled in the rendered
configuration. Gateway SSH and HTTPS are reachable only through the catalog's
Ops administration rule, rather than from every Infra-VLAN client.

## Required policy

Default policy is stateful deny. Rules are evaluated on the interface where a
connection originates.

- WAN: deny by default; forward TCP `80` and `443` only to Door
  (`172.16.30.10`) and only the declared game ports to Games
  (`172.16.30.20`; currently Minecraft TCP `25565`). Do not expose Gateway,
  Infra, or Internal hosts.
- All VLANs: allow DNS only to the selected resolvers, NTP, and outbound TCP
  `80`/`443` for package updates and image pulls. Ops alone also needs outbound
  TCP `22` for Git over SSH. These are permanent shared bootstrap rules, not
  per-VM exceptions.
- Ops: permit administration to guest TCP `22` and Gateway management.
- Monitoring: permit only ICMP, TCP `9100` to guest exporters and Proxmox, and
  TCP `9150` to Games. Guests may send logs only to Monitoring TCP `3100`.
- Door: permit only its named Apps backends on TCP `3005`, `8200`, `8280`, and
  `9000`, plus Monitoring TCP `3000`. DMZ otherwise cannot initiate broad
  private-network access.

Model hosts, networks, and port lists as OPNsense aliases. This keeps the rules
small, auditable, and API-manageable rather than requiring console edits during
each rebuild.

## Verification gate

Before `gateway_policy_ready` is changed, verify from Ops:

- each planned guest gateway responds;
- DNS resolves an IPv4 package endpoint;
- each VLAN reaches public TCP `80` and `443`;
- Ops reaches every guest over TCP `22`;
- Door reaches only the explicitly named backend ports; and
- WAN access reaches only Door `80`/`443` and the declared Games ports.

The Ansible bootstrap's network preflight is a final assertion, not the step
that establishes connectivity. A failure means stop at the Gateway policy; do
not add a one-off shell rule to continue provisioning.

## Tailscale

Gateway is the sole tailnet node. It advertises the three VLAN routes with
source NAT enabled, so every workload sees Gateway as the return path and its
existing VLAN rules remain authoritative. Do not enable Tailscale SSH, an exit
node, Funnel, Serve, or Tailscale on Door/workloads.

After Ops exists, run the Gateway reconciliation playbook. It uses the same
encrypted input used to build Gateway:

```bash
cd ~/homelab/ansible
ansible-playbook playbooks/gateway-tailscale.yml
```

Then apply the separate `terraform/environments/labyrinthian-estate/tailscale`
root with its scoped OAuth credentials. Its policy makes route approval
automatic for `tag:gateway`; inviting somebody to the tailnet is all that is
needed for them to use the VPN.
