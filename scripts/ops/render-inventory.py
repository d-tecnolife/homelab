#!/usr/bin/env python3
"""Render the ignored Ansible inventory from the canonical workload catalog."""

from __future__ import annotations

import argparse
from ipaddress import ip_interface
from pathlib import Path

import yaml


def render_inventory(catalog: dict, *, ops_host=None, proxmox_host=None) -> dict:
    workloads = catalog["workloads"]
    controllers = catalog["controllers"]
    if set(workloads) & set(controllers):
        raise ValueError("Workload names must not shadow controllers")
    hosts = {
        "ops": {
            "ansible_host": str(ip_interface(ops_host or controllers["ops"]["address"]).ip),
            "ansible_connection": "local",
        },
        **{
            name: {"ansible_host": str(ip_interface(spec["address"]).ip)}
            for name, spec in workloads.items()
        },
    }
    proxmox_address = proxmox_host or controllers["proxmox"]["address"]
    addresses = [host["ansible_host"] for host in hosts.values()] + [proxmox_address]
    if len(addresses) != len(set(addresses)):
        raise ValueError("Inventory hosts must have unique addresses")
    return {
        "all": {
            "children": {
                "managed_vms": {"hosts": hosts, "vars": {"ansible_user": "dtec"}},
                "proxmox_hosts": {
                    "hosts": {"proxmox": {"ansible_host": proxmox_address, "ansible_user": "root"}}
                },
            }
        }
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--ops-host", help="Match an environment-specific Terraform Ops address override")
    parser.add_argument("--proxmox-host", help="Proxmox IP or DNS hostname (not the Terraform HTTPS URL)")
    args = parser.parse_args()

    catalog = yaml.safe_load(args.catalog.read_text(encoding="utf-8"))
    inventory = render_inventory(catalog, ops_host=args.ops_host, proxmox_host=args.proxmox_host)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(yaml.safe_dump(inventory, sort_keys=False), encoding="utf-8")


if __name__ == "__main__":
    main()
