# pfSense configuration

Terraform supplies the VM, ISO, WAN NIC, and VLAN trunk. Configure pfSense
from its local Proxmox console before starting dependent Ubuntu VMs.

## Interfaces and DNS

- WAN: `192.168.1.2/24`, upstream gateway `192.168.1.1`; disable **Block private
  networks** because the upstream WAN is RFC1918.
- VLAN 10 (Infra): `172.16.10.1/24`; VLAN 20 (Internal): `172.16.20.1/24`; VLAN
  30 (DMZ): `172.16.30.1/24`, all on the tagged LAN trunk.
- Use split DNS with host overrides for internal names. Do not enable NAT
  reflection.
- The guest topology is IPv4-only. Guest configuration prefers IPv4 so public
  package repositories do not attempt an unrouted IPv6 path.

## Firewall and NAT policy

Use stateful default-deny rules. Permit VLAN DNS, NTP, and required Internet
egress. WAN has no general allow rule: port-forward and pass TCP 80 and 443
only to Door (`172.16.30.10`, running Caddy), and only the exact required game ports to Games
(`172.16.30.20`; currently Minecraft TCP 25565). Never expose pfSense, Infra,
or Internal hosts on WAN.

Allow Ops (`172.16.10.10`) to administer hosts on explicitly required ports.
Allow Monitoring (`172.16.10.20`) only to monitored hosts on ICMP and exact
agent/exporter ports. Allow Door only to its named backends: Apps TCP
8280, 8200, 9000, and 3005; Monitoring TCP 3000. Do not allow a broad DMZ to
private-networks rule. Keep deny logging enabled to validate policy without
opening access broadly.

Export the pfSense configuration after changes and store it through the existing
encrypted recovery workflow. Treat that encrypted export as the pfSense
recovery artifact: restoring it after a console installation must recreate the
interfaces, VLANs, DNS overrides, NAT, and rules together rather than requiring
a second manual click-through. Test DNS, egress, each allowed flow, a denied
cross-VLAN flow, Door HTTPS, and the game port before considering the rebuild
complete.

## Rebuild bootstrap egress

Create these aliases and rules **before** running the Ops bootstrap. This is a
small shared egress policy for every guest, not an ever-growing list of
per-playbook exceptions. Place the pass rules above VLAN deny/reject rules.

| Alias / rule | Value |
| --- | --- |
| `LAB_GUESTS` | `172.16.10.10`, `.20`, `.30`, `.40`; `172.16.20.10`, `.20`; `172.16.30.10`, `.20` |
| `PUBLIC_IPV4` | Inverted destination alias `PRIVATE_NETWORKS` containing `10.0.0.0/8`, `100.64.0.0/10`, `172.16.0.0/12`, and `192.168.0.0/16` |
| `CLOUDFLARE_DNS` | `1.1.1.1`, `1.0.0.1` |
| guest DNS | `LAB_GUESTS` → `CLOUDFLARE_DNS`, TCP/UDP `53` |
| guest time | `LAB_GUESTS` → `PUBLIC_IPV4`, UDP `123` |
| guest bootstrap and updates | `LAB_GUESTS` → `PUBLIC_IPV4`, TCP `80,443` |
| Ops Git SSH | `172.16.10.10` → `PUBLIC_IPV4`, TCP `22` |
| Door NetBird traversal | `172.16.30.10` → NetBird STUN/TURN endpoints, UDP `80,443,3478,5555` |

The shared web-egress rule is required for Ubuntu updates, Docker and Grafana
repositories, Docker image pulls, SOPS, Caddy/CrowdSec, GitHub, and the Nolife
development tools. It grants no inbound WAN access and, by excluding private
ranges, does not create a broad inter-VLAN rule. NetBird clients need no
inbound firewall opening; their control and traversal connections are outbound.

Then add the intentionally narrow private-network flows below:

| Source | Destination | Protocol / ports | Purpose |
| --- | --- | --- | --- |
| Ops | all managed guests | TCP `22` | administration and Ansible |
| Monitoring | all guests and Proxmox | TCP `9100`; Games TCP `9150` | Prometheus scraping |
| all guests | Monitoring | TCP `3100` | Alloy → Loki log delivery |
| Door | Apps | TCP `3005,8200,8280,9000` | published Caddy backends |
| Door | Monitoring | TCP `3000` | published Grafana backend |

When adding a new published Docker app, add exactly one Door-to-backend rule
for its listening port and one Caddy site. Do not add a general DMZ-to-Internal
allow rule.
