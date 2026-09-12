import copy
import ipaddress
import pathlib
import re
import subprocess
import sys
import tempfile
import unittest
from importlib.util import module_from_spec, spec_from_file_location

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/ops/render-inventory.py"
spec = spec_from_file_location("render_inventory", SCRIPT)
renderer = module_from_spec(spec)
spec.loader.exec_module(renderer)


class InventoryTests(unittest.TestCase):
    def setUp(self):
        self.catalog = yaml.safe_load((ROOT / "topology/workloads.yaml").read_text())

    def test_cli_contains_all_catalog_hosts_and_only_ops_is_local(self):
        with tempfile.TemporaryDirectory() as directory:
            output = pathlib.Path(directory) / "inventory.yml"
            subprocess.run([sys.executable, str(SCRIPT), "--catalog",
                            str(ROOT / "topology/workloads.yaml"), "--output", str(output)], check=True)
            inventory = yaml.safe_load(output.read_text())["all"]["children"]
        hosts = inventory["managed_vms"]["hosts"]
        self.assertEqual(set(hosts), {"ops", *self.catalog["workloads"]})
        self.assertEqual(inventory["managed_vms"]["vars"]["ansible_user"], "dtec")
        self.assertEqual([name for name, host in hosts.items() if host.get("ansible_connection") == "local"], ["ops"])
        for name, vm in self.catalog["workloads"].items():
            self.assertEqual(hosts[name]["ansible_host"], str(ipaddress.ip_interface(vm["address"]).ip))
        self.assertEqual(inventory["proxmox_hosts"]["hosts"]["proxmox"]["ansible_user"], "root")

    def test_endpoint_overrides_preserve_ops_local_connection(self):
        groups = renderer.render_inventory(self.catalog, ops_host="172.16.10.11", proxmox_host="pve.example.test")["all"]["children"]
        self.assertEqual(groups["managed_vms"]["hosts"]["ops"], {"ansible_host": "172.16.10.11", "ansible_connection": "local"})
        self.assertEqual(groups["proxmox_hosts"]["hosts"]["proxmox"]["ansible_host"], "pve.example.test")

    def test_rejects_shadowed_controllers_duplicate_and_invalid_addresses(self):
        for name, address in [("ops", "172.16.10.50/24"), ("new", "172.16.10.10/24"), ("new", "not-an-ip")]:
            with self.subTest(name=name, address=address):
                catalog = copy.deepcopy(self.catalog)
                catalog["workloads"][name] = {"address": address}
                with self.assertRaises(ValueError):
                    renderer.render_inventory(catalog)

    def test_default_endpoints_match_terraform_and_gateway_aliases(self):
        # Terraform preserves public variable overrides; detect drift in their
        # defaults without loading any local tfvars, state, or secret input.
        tfroot = ROOT / "terraform/environments/labyrinthian-estate"
        variables = (tfroot / "variables.tf").read_text()
        default = re.search(r'variable "ops_ipv4_address" \{.*?default\s*=\s*"([^"]+)"', variables, re.S)
        self.assertEqual(default.group(1), self.catalog["controllers"]["ops"]["address"])
        example = (tfroot / "terraform.tfvars.example").read_text()
        endpoint = re.search(r'proxmox_endpoint\s*=\s*"https://([^:/]+)', example)
        self.assertEqual(endpoint.group(1), self.catalog["controllers"]["proxmox"]["address"])
        baseline = yaml.safe_load((ROOT / "gateway/baseline.yaml").read_text())
        hosts = renderer.render_inventory(self.catalog)["all"]["children"]["managed_vms"]["hosts"]
        for name, alias in baseline["aliases"].items():
            if name in hosts:
                self.assertEqual(alias["values"], [hosts[name]["ansible_host"]], name)


if __name__ == "__main__":
    unittest.main()
