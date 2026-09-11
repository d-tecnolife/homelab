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


def load_renderer(catalog, workloads):
    yaml = types.SimpleNamespace(
        safe_load=lambda content: workloads if "workloads:" in content else catalog
    )
    spec = spec_from_file_location("gateway_renderer", RENDERER)
    module = module_from_spec(spec)
    with mock.patch.dict(sys.modules, {"yaml": yaml}):
        spec.loader.exec_module(module)
    return module


class GatewayRendererTests(unittest.TestCase):
    def test_renders_wan_forwards_and_split_dns(self):
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
                "system": {"hostname": "gateway", "domain": "dscim.dev", "timezone": "America/Winnipeg", "wan_block_bogon_networks": True},
                "interfaces": {
                    "wan": {"device": "vtnet0", "address": "192.168.1.2/24", "gateway": "192.168.1.1"},
                    "infra": {"device": "vlan0", "vlan": {"parent": "vtnet1", "id": 10}, "address": "172.16.10.1/24"},
                    "internal": {"device": "vlan1", "vlan": {"parent": "vtnet1", "id": 20}, "address": "172.16.20.1/24"},
                    "dmz": {"device": "vlan2", "vlan": {"parent": "vtnet1", "id": 30}, "address": "172.16.30.1/24"},
                },
                "aliases": {},
                "firewall": {
                    "outbound_nat": "automatic",
                    "rules": [{"interface": ["infra", "internal", "dmz"], "action": "pass", "protocol": "tcp/udp", "source": "interface_network", "destination": "this_firewall", "ports": "dns_ports", "description": "Gateway split DNS"}],
                    "port_forwards": [
                        {"interface": "wan", "protocol": "tcp", "destination_port": 80, "target": "door", "target_port": 80, "description": "WAN HTTP to Door"},
                        {"interface": "wan", "protocol": "tcp", "destination_port": 443, "target": "door", "target_port": 443, "description": "WAN HTTPS to Door"},
                        {"interface": "wan", "protocol": "tcp", "destination_port": 25565, "target": "games", "target_port": 25565, "description": "WAN Minecraft to Games"},
                    ],
                },
            }
            workloads = {"workloads": {name: {"address": address} for name, address in {
                "gitea": "172.16.10.30/24", "monitoring": "172.16.10.20/24", "k3s": "172.16.10.40/24", "apps": "172.16.20.10/24", "nolife": "172.16.20.20/24", "door": "172.16.30.10/24", "games": "172.16.30.20/24"
            }.items()}}
            renderer = load_renderer(catalog, workloads)
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
                    "--workloads",
                    str(ROOT / "topology/workloads.yaml"),
                    "--ssh-public-key",
                    str(key),
                    "--output",
                    str(output),
                ],
            ):
                renderer.main()
            tree = ET.parse(output)

            self.assertEqual(tree.findtext("./system/noantilockout"), "1")
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
            self.assertEqual(tree.findtext("./OPNsense/unboundplus/general/enabled"), "1")
            hosts = tree.findall("./OPNsense/unboundplus/hosts/host")
            self.assertEqual({host.findtext("hostname") for host in hosts}, {"gitea", "monitoring", "k3s", "apps", "nolife", "door", "games"})
            rules = tree.findall("./OPNsense/Firewall/Filter/rules/rule")
            self.assertTrue(any(rule.findtext("description") == "Gateway split DNS" for rule in rules))


if __name__ == "__main__":
    unittest.main()
