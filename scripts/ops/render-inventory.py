#!/usr/bin/env python3
"""Render the ignored Ansible inventory from the canonical workload catalog."""

from __future__ import annotations

import argparse
from pathlib import Path

import yaml


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--proxmox-host", default="192.168.1.100")
    args = parser.parse_args()

    catalog = yaml.safe_load(args.catalog.read_text(encoding="utf-8"))
    workloads = catalog["workloads"]
    hosts = {
        "ops": {"ansible_host": "172.16.10.10", "ansible_connection": "local"},
        **{
            name: {"ansible_host": str(spec["address"]).split("/", 1)[0]}
            for name, spec in workloads.items()
        },
    }
    inventory = {
        "all": {
            "children": {
                "managed_vms": {"hosts": hosts, "vars": {"ansible_user": "dtec"}},
                "proxmox_hosts": {
                    "hosts": {"proxmox": {"ansible_host": args.proxmox_host, "ansible_user": "root"}}
                },
            }
        }
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(yaml.safe_dump(inventory, sort_keys=False), encoding="utf-8")


if __name__ == "__main__":
    main()
