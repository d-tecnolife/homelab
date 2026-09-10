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

## Firewall and NAT policy

Use stateful default-deny rules. Permit VLAN DNS, NTP, and required Internet
egress. WAN has no general allow rule: port-forward and pass TCP 80 and 443
only to Caddy (`172.16.30.10`), and only the exact required game ports to Games
(`172.16.30.20`; currently Minecraft TCP 25565). Never expose pfSense, Infra,
or Internal hosts on WAN.

Allow Ops (`172.16.10.10`) to administer hosts on explicitly required ports.
Allow Monitoring (`172.16.10.20`) only to monitored hosts on ICMP and exact
agent/exporter ports. Allow Caddy only to its named backends: Apps TCP
8280, 8200, 9000, and 3005; Monitoring TCP 3000. Do not allow a broad DMZ to
private-networks rule. Keep deny logging enabled to validate policy without
opening access broadly.

Export the pfSense configuration after changes and store it through the existing
encrypted recovery workflow. Treat that encrypted export as the pfSense
recovery artifact: restoring it after a console installation must recreate the
interfaces, VLANs, DNS overrides, NAT, and rules together rather than requiring
a second manual click-through. Test DNS, egress, each allowed flow, a denied
cross-VLAN flow, Caddy HTTPS, and the game port before considering the rebuild
complete.
