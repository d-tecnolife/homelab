#!/usr/bin/env python3
"""Collect one compact JSON health document for the homelab."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import pathlib
import subprocess
import tempfile
from typing import Any


DEFAULT_ANSIBLE_DIR = pathlib.Path("/home/dtec/homelab/ansible")
DEFAULT_PROBE = pathlib.Path("/usr/local/libexec/homelab-health-probe.py")


def invoke_ansible(
    ansible_dir: pathlib.Path,
    inventory: pathlib.Path,
    probe: pathlib.Path,
    timeout: int,
) -> tuple[int, dict[str, Any]]:
    with tempfile.TemporaryDirectory(prefix="homelab-health-") as tree_name:
        tree = pathlib.Path(tree_name)
        env = os.environ.copy()
        env["ANSIBLE_CONFIG"] = str(ansible_dir / "ansible.cfg")
        command = [
            "ansible",
            "managed_vms",
            "--inventory",
            str(inventory),
            "--module-name",
            "ansible.builtin.script",
            "--args",
            f"{probe} --host {{{{ inventory_hostname }}}} --timeout {timeout:d}",
            "--tree",
            str(tree),
            "--become",
            "--forks",
            "16",
            "--timeout",
            f"{timeout:d}",
        ]
        try:
            completed = subprocess.run(
                command,
                cwd=ansible_dir,
                env=env,
                check=False,
                capture_output=True,
                text=True,
                timeout=max(20, timeout * 6),
            )
            return completed.returncode, read_result_tree(tree)
        except subprocess.TimeoutExpired:
            return 124, read_result_tree(tree)
        except FileNotFoundError:
            return 127, {}


def read_result_tree(tree: pathlib.Path) -> dict[str, Any]:
    results: dict[str, Any] = {}
    for path in sorted(tree.iterdir()) if tree.exists() else []:
        try:
            envelope = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            results[path.name] = {"reachable": False, "reason": "invalid_result"}
            continue
        if envelope.get("unreachable"):
            results[path.name] = {"reachable": False, "reason": "unreachable"}
            continue
        if envelope.get("failed") or envelope.get("rc", 0) != 0:
            results[path.name] = {"reachable": True, "probe": "failed"}
            continue
        try:
            snapshot = json.loads(envelope.get("stdout", ""))
        except (TypeError, json.JSONDecodeError):
            results[path.name] = {"reachable": True, "probe": "invalid_output"}
            continue
        results[path.name] = {"reachable": True, **snapshot}
    return results


def calculate_status(hosts: dict[str, Any], invocation_rc: int) -> str:
    if invocation_rc != 0 or not hosts:
        return "degraded"
    for host in hosts.values():
        if not host.get("reachable") or host.get("probe"):
            return "degraded"
        containers = host.get("containers", {})
        if containers.get("engine") is not None and (
            containers["engine"] != "active" or not containers.get("available")
        ):
            return "degraded"
        for container in containers.get("items", []):
            if container["state"] != "running" or container.get("health") == "unhealthy":
                return "degraded"
        if any(
            exporter["state"] not in ("active", "running")
            for exporter in host.get("exporters", [])
        ):
            return "degraded"
        prometheus = host.get("prometheus")
        if prometheus and (
            not prometheus["reachable"]
            or any(target["health"] != "up" for target in prometheus["targets"])
        ):
            return "degraded"
        caddy = host.get("caddy")
        if caddy and (caddy["service"] != "active" or not caddy["health_endpoint"]):
            return "degraded"
        minecraft = host.get("minecraft")
        if minecraft and (minecraft["container"] != "running" or not minecraft["port_25565"]):
            return "degraded"
        crowdsec = host.get("crowdsec")
        if crowdsec and (
            crowdsec["service"] != "active" or crowdsec["bouncer"] != "active"
        ):
            return "degraded"
        nftables = host.get("nftables")
        if nftables and (
            nftables["service"] != "active"
            or not nftables["config_valid"]
            or not nftables["ipv4_forwarding"]
        ):
            return "degraded"
    return "ok"


def build_document(hosts: dict[str, Any], invocation_rc: int) -> dict[str, Any]:
    return {
        "status": calculate_status(hosts, invocation_rc),
        "checked_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat(),
        "hosts": hosts,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ansible-dir", type=pathlib.Path, default=DEFAULT_ANSIBLE_DIR)
    parser.add_argument("--inventory", type=pathlib.Path)
    parser.add_argument("--probe", type=pathlib.Path, default=DEFAULT_PROBE)
    parser.add_argument("--timeout", type=int, default=5)
    parser.add_argument("--strict", action="store_true", help="exit nonzero when degraded")
    args = parser.parse_args()
    timeout = max(1, args.timeout)
    inventory = args.inventory or args.ansible_dir / "inventory" / "hosts.yml"
    rc, hosts = invoke_ansible(args.ansible_dir, inventory, args.probe, timeout)
    document = build_document(hosts, rc)
    print(json.dumps(document, separators=(",", ":"), sort_keys=True))
    return 1 if args.strict and document["status"] != "ok" else 0


if __name__ == "__main__":
    raise SystemExit(main())
