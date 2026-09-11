#!/usr/bin/env python3
"""Render the secret-free Gateway policy catalog as an OPNsense config.xml."""

from __future__ import annotations

import argparse
import base64
import os
from pathlib import Path
import subprocess
from xml.etree import ElementTree as ET

import yaml


INTERFACES = {"infra": "lan", "internal": "opt1", "dmz": "opt2", "wan": "wan"}


def child(parent: ET.Element, name: str, value: object | None = None) -> ET.Element:
    element = ET.SubElement(parent, name)
    if value is not None:
        element.text = str(value)
    return element


def ports(value: object) -> str:
    if isinstance(value, list):
        return ",".join(str(item) for item in value)
    return str(value)


def rule(parent: ET.Element, spec: dict, interface: str, sequence: int) -> None:
    item = child(parent, "rule")
    for key, value in {
        "enabled": 1,
        "statetype": "keep",
        "sequence": sequence,
        "action": spec["action"],
        "quick": 1,
        "interfacenot": 0,
        "interface": INTERFACES[interface],
        "direction": "in",
        "ipprotocol": "inet",
        "protocol": spec["protocol"],
        "source_net": INTERFACES[interface] if spec["source"] == "interface_network" else spec["source"],
        "source_not": 0,
        "destination_net": spec["destination"].removeprefix("!"),
        "destination_not": int(str(spec["destination"]).startswith("!")),
        "disablereplyto": 0,
        "log": 0,
        "allowopts": 0,
        "nosync": 0,
        "nopfsync": 0,
        "tcpflags_any": 0,
        "description": spec["description"],
    }.items():
        child(item, key, value)
    if "ports" in spec:
        child(item, "destination_port", ports(spec["ports"]))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--ssh-public-key", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    password = os.environ.get("GATEWAY_ROOT_PASSWORD")
    if not password:
        raise SystemExit("GATEWAY_ROOT_PASSWORD must be supplied from encrypted deployment input")
    result = subprocess.run(
        ["htpasswd", "-i", "-nB", "root"],
        input=f"{password}\n",
        text=True,
        capture_output=True,
        check=True,
    )
    password_hash = result.stdout.rstrip("\n").split(":", 1)[1]
    catalog = yaml.safe_load(args.catalog.read_text(encoding="utf-8"))
    root = ET.Element("opnsense")
    system = child(root, "system")
    for key in ("hostname", "domain", "timezone"):
        child(system, key, catalog["system"][key])
    child(system, "dnsallowoverride", 0)
    child(system, "disablenatreflection", "yes")
    ssh = child(system, "ssh")
    child(ssh, "enable", 1)
    child(ssh, "permitrootlogin", 1)
    child(ssh, "passwordauth", 0)
    group = child(system, "group")
    for key, value in {"name": "admins", "scope": "system", "gid": 1999, "member": 0, "priv": "page-all"}.items():
        child(group, key, value)
    user = child(system, "user")
    public_key = args.ssh_public_key.read_text(encoding="utf-8").strip().encode()
    for key, value in {"name": "root", "scope": "system", "groupname": "admins", "password": password_hash, "authorizedkeys": base64.b64encode(public_key).decode(), "uid": 0}.items():
        child(user, key, value)

    vlans = child(root, "vlans")
    interfaces = child(root, "interfaces")
    for name, spec in catalog["interfaces"].items():
        if "vlan" in spec:
            vlan = child(vlans, "vlan")
            for key, value in {"if": spec["vlan"]["parent"], "tag": spec["vlan"]["id"], "pcp": 0, "descr": name, "vlanif": spec["device"]}.items():
                child(vlan, key, value)
        interface = child(interfaces, INTERFACES[name])
        child(interface, "enable", 1)
        child(interface, "if", spec["device"])
        address, prefix = spec["address"].split("/")
        child(interface, "ipaddr", address)
        child(interface, "subnet", prefix)
        if name == "wan":
            child(interface, "gateway", "WAN_GW")
            if catalog["system"]["wan_block_bogon_networks"]:
                child(interface, "blockbogons", 1)

    gateways = child(root, "gateways")
    child(gateways, "defaultgw", "WAN_GW")
    gateway = child(gateways, "gateway_item")
    for key, value in {"interface": "wan", "gateway": catalog["interfaces"]["wan"]["gateway"], "name": "WAN_GW", "weight": 1}.items():
        child(gateway, key, value)
    nat = child(root, "nat")
    child(child(nat, "outbound"), "mode", catalog["firewall"]["outbound_nat"])

    model = child(child(root, "OPNsense"), "Firewall")
    aliases = child(child(model, "Alias"), "aliases")
    for name, spec in catalog["aliases"].items():
        alias = child(aliases, "alias")
        for key, value in {"enabled": 1, "name": name, "type": spec["type"], "content": "\n".join(map(str, spec["values"]))}.items():
            child(alias, key, value)
    rules = child(child(model, "Filter"), "rules")
    sequence = 10
    for spec in catalog["firewall"]["rules"]:
        for interface in spec["interface"] if isinstance(spec["interface"], list) else [spec["interface"]]:
            rule(rules, spec, interface, sequence)
            sequence += 10
    ET.indent(root, space="  ")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(root).write(args.output, encoding="utf-8", xml_declaration=True)


if __name__ == "__main__":
    main()
