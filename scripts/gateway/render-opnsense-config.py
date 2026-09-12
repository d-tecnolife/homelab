#!/usr/bin/env python3
"""Render the secret-free Gateway policy catalog as an OPNsense config.xml."""

from __future__ import annotations

import argparse
import base64
import os
from pathlib import Path
import secrets
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


def sha512_crypt(value: str) -> str:
    """Return the FreeBSD-compatible SHA-512 crypt hash OPNsense stores."""
    result = subprocess.run(
        ["openssl", "passwd", "-6", "-stdin"],
        input=f"{value}\n",
        text=True,
        capture_output=True,
        check=True,
    )
    return result.stdout.strip()


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


def port_forward(parent: ET.Element, spec: dict, sequence: int) -> None:
    item = child(parent, "rule")
    for key, value in {
        "sequence": sequence,
        "interface": INTERFACES[spec["interface"]],
        "ipprotocol": "inet",
        "protocol": spec["protocol"],
        "target": spec["target"],
        "local-port": spec["target_port"],
        "descr": spec["description"],
        # Split DNS supplies internal answers; never generate hairpin rules.
        "natreflection": "disable",
        # Permit only the translated flow; this is not a broad WAN rule.
        "pass": "pass",
    }.items():
        child(item, key, value)
    source = child(item, "source")
    child(source, "any", 1)
    destination = child(item, "destination")
    child(destination, "network", "wanip")
    child(destination, "port", spec["destination_port"])


# Unbound's own enable/port/dnssec/local_zone_type settings are deliberately
# NOT rendered here. That's a versioned OPNsense MVC model
# (OPNsense\Unbound\Unbound, migrations 1.0.0-1.0.15); a hand-rendered
# section never gets the model-version stamp OPNsense's own save path adds,
# and without it the "enabled" flag reads back correctly but the daemon
# never actually starts -- confirmed on a from-scratch rebuild. That part is
# now owned by terraform/environments/labyrinthian-estate/opnsense (the
# opnsense_unbound_settings resource), which manages it through the live
# API instead. This function only seeds split-DNS host overrides, which are
# harmless static data: the first time the Terraform resource above saves
# any part of this same model, OPNsense re-serializes the whole object
# (hosts included), giving these entries the correct versioning as a
# side effect -- no separate resource needed for them.
def add_unbound_host_overrides(root: ET.Element, catalog: dict, workloads: dict) -> None:
    unbound = child(child(root, "OPNsense"), "unboundplus")
    hosts = child(unbound, "hosts")
    for name, spec in workloads.items():
        host = child(hosts, "host")
        for key, value in {
            "enabled": 1,
            "hostname": name,
            "domain": catalog["system"]["domain"],
            "rr": "A",
            "server": spec["address"].split("/", 1)[0],
            "addptr": 1,
            "description": f"Homelab {name}",
        }.items():
            child(host, key, value)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--workloads", type=Path, required=True)
    parser.add_argument("--ssh-public-key", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    password = os.environ.get("GATEWAY_ROOT_PASSWORD")
    api_key = os.environ.get("OPNSENSE_API_KEY")
    api_secret = os.environ.get("OPNSENSE_API_SECRET")
    if not all((password, api_key, api_secret)):
        raise SystemExit(
            "GATEWAY_ROOT_PASSWORD, OPNSENSE_API_KEY, and OPNSENSE_API_SECRET "
            "must be supplied from encrypted deployment input"
        )
    result = subprocess.run(
        ["htpasswd", "-i", "-nB", "root"],
        input=f"{password}\n",
        text=True,
        capture_output=True,
        check=True,
    )
    password_hash = result.stdout.rstrip("\n").split(":", 1)[1]
    catalog = yaml.safe_load(args.catalog.read_text(encoding="utf-8"))
    workloads = yaml.safe_load(args.workloads.read_text(encoding="utf-8"))["workloads"]
    root = ET.Element("opnsense")
    system = child(root, "system")
    for key in ("hostname", "domain", "timezone"):
        child(system, key, catalog["system"][key])
    child(system, "dnsallowoverride", 0)
    for resolver in catalog["system"]["dns_resolvers"]:
        child(system, "dnsserver", resolver)
    child(system, "disablenatreflection", "yes")
    webgui = child(system, "webgui")
    # OPNsense's supported sample configuration explicitly declares HTTPS.
    # Without it, an imported minimal config can leave the API endpoint on an
    # unexpected protocol and strand the automated bootstrap controller.
    child(webgui, "protocol", "https")
    # Keep OPNsense's built-in LAN anti-lockout path on VLAN 10. This is the
    # bootstrap control plane for the Gateway API before Tailscale and guest
    # automation exist; disabling it creates an unrecoverable circular
    # dependency if a rendered policy does not load. WAN remains default-deny.
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
    # This account is API-only: its web-login password is random and discarded.
    # The Tailscale plugin exposes an authentication endpoint outside its narrow
    # ACL, so page-all is required until the upstream plugin narrows that API.
    automation_user = child(system, "user")
    for key, value in {
        "name": "homelab-automation",
        "scope": "user",
        "uid": 2000,
        "disabled": 0,
        "password": sha512_crypt(secrets.token_urlsafe(48)),
        "priv": "page-all",
        "descr": "Homelab Gateway bootstrap automation",
    }.items():
        child(automation_user, key, value)
    api_keys = child(automation_user, "apikeys")
    api_key_item = child(api_keys, "item")
    child(api_key_item, "key", api_key)
    child(api_key_item, "secret", sha512_crypt(api_secret))

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
    for sequence, spec in enumerate(catalog["firewall"]["port_forwards"], start=1):
        port_forward(nat, spec, sequence)

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
    settings = child(model, "settings")
    child(child(settings, "nat"), "snat_mode", catalog["firewall"]["outbound_nat"])
    add_unbound_host_overrides(root, catalog, workloads)
    ET.indent(root, space="  ")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(root).write(args.output, encoding="utf-8", xml_declaration=True)


if __name__ == "__main__":
    main()
