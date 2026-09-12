import os
import pathlib
import sys
import tempfile
import types
import unittest
from importlib.util import module_from_spec, spec_from_file_location
from unittest import mock
from xml.etree import ElementTree as ET


ROOT = pathlib.Path(__file__).parents[1]
RENDERER = ROOT / "scripts/gateway/render-opnsense-config.py"


def load_renderer(catalog):
    yaml = types.SimpleNamespace(safe_load=lambda content: catalog)
    spec = spec_from_file_location("gateway_renderer", RENDERER)
    module = module_from_spec(spec)
    with mock.patch.dict(sys.modules, {"yaml": yaml}):
        spec.loader.exec_module(module)
    return module


class GatewayRendererTests(unittest.TestCase):
    def test_renders_wan_forwards_and_firewall_policy(self):
        with tempfile.TemporaryDirectory() as directory:
            output = pathlib.Path(directory) / "config.xml"
            key = pathlib.Path(directory) / "gateway.pub"
            key.write_text("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITest gateway-test\\n")
            environment = os.environ | {
                "GATEWAY_ROOT_PASSWORD": "test-root-password",
                "OPNSENSE_API_KEY": "test-api-key",
                "OPNSENSE_API_SECRET": "test-api-secret",
            }
            catalog = {
                "system": {"hostname": "gateway", "domain": "dscim.dev", "timezone": "America/Winnipeg", "dns_resolvers": ["1.1.1.1", "1.0.0.1"], "wan_block_bogon_networks": True},
                "interfaces": {
                    "wan": {"device": "vtnet0", "address": "192.168.1.2/24", "gateway": "192.168.1.1"},
                    "infra": {"device": "vlan0", "vlan": {"parent": "vtnet1", "id": 10}, "address": "172.16.10.1/24"},
                    "internal": {"device": "vlan1", "vlan": {"parent": "vtnet1", "id": 20}, "address": "172.16.20.1/24"},
                    "dmz": {"device": "vlan2", "vlan": {"parent": "vtnet1", "id": 30}, "address": "172.16.30.1/24"},
                },
                "aliases": {},
                "firewall": {
                    "outbound_nat": "automatic",
                    "rules": [
                        {"interface": "infra", "action": "pass", "protocol": "tcp", "source": "interface_network", "destination": "!private_networks", "ports": [22], "description": "Public Git SSH - Infra"},
                        {"interface": "internal", "action": "pass", "protocol": "tcp", "source": "interface_network", "destination": "!private_networks", "ports": [22], "description": "Public Git SSH - Internal"},
                        {"interface": "dmz", "action": "pass", "protocol": "tcp", "source": "interface_network", "destination": "!private_networks", "ports": [22], "description": "Public Git SSH - DMZ"},
                        {"interface": "infra", "action": "pass", "protocol": "tcp", "source": "ops", "destination": "this_firewall", "ports": [22], "description": "Ops Gateway administration"},
                        {"interface": "infra", "action": "pass", "protocol": "tcp", "source": "monitoring", "destination": "homelab_networks", "ports": "exporter_ports", "description": "Monitoring exporters"},
                    ],
                    "port_forwards": [
                        {"interface": "wan", "protocol": "tcp", "destination_port": 80, "target": "door", "target_port": 80, "description": "WAN HTTP to Door"},
                        {"interface": "wan", "protocol": "tcp", "destination_port": 443, "target": "door", "target_port": 443, "description": "WAN HTTPS to Door"},
                        {"interface": "wan", "protocol": "tcp", "destination_port": 25565, "target": "games", "target_port": 25565, "description": "WAN Minecraft to Games"},
                    ],
                },
            }
            renderer = load_renderer(catalog)
            with mock.patch.dict(os.environ, environment, clear=True), mock.patch.object(
                renderer.subprocess,
                "run",
                return_value=mock.Mock(stdout="root:$6$test-hash\\n"),
            ), mock.patch.object(
                sys,
                "argv",
                [
                    str(RENDERER),
                    "--catalog",
                    str(ROOT / "gateway/baseline.yaml"),
                    "--ssh-public-key",
                    str(key),
                    "--output",
                    str(output),
                ],
            ):
                renderer.main()
            tree = ET.parse(output)

            self.assertIsNone(tree.find("./system/noantilockout"))
            self.assertEqual(tree.findtext("./system/webgui/protocol"), "https")
            self.assertEqual(
                [server.text for server in tree.findall("./system/dnsserver")],
                ["1.1.1.1", "1.0.0.1"],
            )
            self.assertEqual(tree.findtext("./interfaces/wan/if"), "vtnet0")
            self.assertEqual(tree.findtext("./interfaces/lan/if"), "vlan0")
            self.assertEqual(tree.findtext("./interfaces/opt1/if"), "vlan1")
            self.assertEqual(tree.findtext("./interfaces/opt2/if"), "vlan2")
            self.assertEqual(
                [
                    (vlan.findtext("if"), vlan.findtext("tag"), vlan.findtext("vlanif"))
                    for vlan in tree.findall("./vlans/vlan")
                ],
                [("vtnet1", "10", "vlan0"), ("vtnet1", "20", "vlan1"), ("vtnet1", "30", "vlan2")],
            )
            forwards = tree.findall("./nat/rule")
            self.assertEqual(
                [(rule.findtext("destination/port"), rule.findtext("target")) for rule in forwards],
                [("80", "door"), ("443", "door"), ("25565", "games")],
            )
            self.assertTrue(all(rule.findtext("natreflection") == "disable" for rule in forwards))
            self.assertTrue(all(rule.findtext("pass") == "pass" for rule in forwards))
            # Unbound is not rendered here at all -- every internal service
            # this homelab needs a name for already has a public DNS record,
            # so Gateway has no split-DNS role; guests and Gateway itself use
            # the public resolvers in ./system/dnsserver directly.
            self.assertIsNone(tree.find("./OPNsense/unboundplus"))
            rules = tree.findall("./OPNsense/Firewall/Filter/rules/rule")
            self.assertEqual(
                {rule.findtext("description") for rule in rules if rule.findtext("description").startswith("Public Git SSH")},
                {"Public Git SSH - Infra", "Public Git SSH - Internal", "Public Git SSH - DMZ"},
            )
            # OPNsense only understands (self) here. Rendering the catalog's
            # readable "this_firewall" verbatim produces a rule that loads,
            # enables, and never matches -- which is how SSH to Gateway was
            # silently unreachable while the GUI stayed up on the built-in
            # anti-lockout rule.
            administration = [
                rule for rule in rules
                if rule.findtext("description") == "Ops Gateway administration"
            ]
            self.assertEqual(len(administration), 1)
            self.assertEqual(administration[0].findtext("destination_net"), "(self)")
            self.assertEqual(administration[0].findtext("destination_port"), "22")
            # OPNsense's rule model accepts one port, a range, or a port alias.
            # A comma-joined list renders fine into config.xml but is rejected
            # the moment the same rule is saved through the API, so a rule that
            # looks correct on a fresh install cannot be reconciled later.
            for rule in rules:
                port = rule.findtext("destination_port")
                if port is not None:
                    self.assertNotIn(
                        ",", port,
                        "%s renders a comma-joined port list" % rule.findtext("description"),
                    )
            self.assertNotIn(
                "this_firewall",
                {rule.findtext("destination_net") for rule in rules},
            )


if __name__ == "__main__":
    unittest.main()
