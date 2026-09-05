#!/usr/bin/env python3
"""Collect a bounded, secret-free health snapshot from one managed VM."""

from __future__ import annotations

import argparse
import json
import socket
import subprocess
import urllib.error
import urllib.request
from typing import Any


def run(argv: list[str], timeout: float) -> tuple[int, str]:
    try:
        completed = subprocess.run(
            argv,
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return completed.returncode, completed.stdout[:262_144]
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return 127, ""


def service_state(unit: str, timeout: float) -> str | None:
    load_rc, load = run(
        ["systemctl", "show", unit, "--property=LoadState", "--value"], timeout
    )
    if load_rc != 0 or load.strip() == "not-found":
        return None
    active_rc, active = run(["systemctl", "is-active", unit], timeout)
    state = active.strip() or "unknown"
    return state if active_rc == 0 else state


DOCKER_HOSTS = {"ops", "apps", "games", "monitoring"}


def container_snapshot(host: str, timeout: float) -> dict[str, Any]:
    engine = service_state("docker.service", timeout)
    rc, output = run(
        [
            "docker",
            "ps",
            "--all",
            "--no-trunc=false",
            "--format",
            "{{json .Names}}\t{{json .State}}\t{{json .Status}}",
        ],
        timeout,
    )
    if rc != 0:
        return {
            "engine": engine or ("missing" if host in DOCKER_HOSTS else None),
            "available": False,
            "items": [],
        }

    items = []
    for line in output.splitlines()[:200]:
        fields = line.split("\t", 2)
        if len(fields) != 3:
            continue
        try:
            name, state, status = (json.loads(field) for field in fields)
        except json.JSONDecodeError:
            continue
        health = None
        if "(healthy)" in status:
            health = "healthy"
        elif "(unhealthy)" in status:
            health = "unhealthy"
        elif "health: starting" in status:
            health = "starting"
        items.append({"name": name, "state": state, "health": health})
    return {
        "engine": engine,
        "available": True,
        "items": sorted(items, key=lambda item: item["name"]),
    }


def http_json(url: str, timeout: float) -> dict[str, Any] | None:
    try:
        with urllib.request.urlopen(url, timeout=timeout) as response:
            if response.status != 200:
                return None
            body = response.read(524_289)
            if len(body) > 524_288:
                return None
            return json.loads(body)
    except (OSError, ValueError, urllib.error.URLError):
        return None


def prometheus_snapshot(
    host: str, containers: dict[str, Any], timeout: float
) -> dict[str, Any] | None:
    container = next(
        (item for item in containers["items"] if item["name"] == "prometheus"), None
    )
    if container is None:
        if host == "monitoring":
            return {"container": "missing", "reachable": False, "targets": []}
        return None
    payload = http_json("http://127.0.0.1:9090/api/v1/targets?state=any", timeout)
    if not payload or payload.get("status") != "success":
        return {"container": container["state"], "reachable": False, "targets": []}

    targets = []
    for target in payload.get("data", {}).get("activeTargets", [])[:200]:
        labels = target.get("labels", {})
        discovered = target.get("discoveredLabels", {})
        targets.append(
            {
                "job": labels.get("job") or discovered.get("job") or "unknown",
                "instance": (
                    labels.get("instance")
                    or discovered.get("__address__")
                    or "unknown"
                ),
                "health": target.get("health", "unknown"),
            }
        )
    return {
        "container": container["state"],
        "reachable": True,
        "targets": sorted(targets, key=lambda target: (target["job"], target["instance"])),
    }


def tcp_open(host: str, port: int, timeout: float) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def caddy_snapshot(host: str, timeout: float) -> dict[str, Any] | None:
    state = service_state("caddy.service", timeout)
    if state is None:
        return {"service": "missing", "health_endpoint": False} if host == "edge" else None
    healthy = False
    try:
        with urllib.request.urlopen("http://127.0.0.1:8080/healthz", timeout=timeout) as response:
            healthy = response.status == 200 and response.read(16).strip() == b"ok"
    except (OSError, urllib.error.URLError):
        pass
    return {"service": state, "health_endpoint": healthy}


def minecraft_snapshot(
    host: str, containers: dict[str, Any], timeout: float
) -> dict[str, Any] | None:
    item = next(
        (item for item in containers["items"] if item["name"] == "minecraft"), None
    )
    if item is None:
        if host == "games":
            return {"container": "missing", "health": None, "port_25565": False}
        return None
    return {
        "container": item["state"],
        "health": item["health"],
        "port_25565": tcp_open("127.0.0.1", 25565, timeout),
    }


def crowdsec_snapshot(host: str, timeout: float) -> dict[str, Any] | None:
    state = service_state("crowdsec.service", timeout)
    if state is None:
        if host == "edge":
            return {"service": "missing", "bouncer": "missing", "decisions": None}
        return None
    bouncer = service_state("crowdsec-firewall-bouncer.service", timeout)
    rc, raw = run(["cscli", "decisions", "list", "-o", "json"], timeout)
    decisions = None
    if rc == 0:
        try:
            value = json.loads(raw)
            decisions = len(value) if isinstance(value, list) else None
        except json.JSONDecodeError:
            pass
    return {"service": state, "bouncer": bouncer, "decisions": decisions}


def nftables_snapshot(host: str, timeout: float) -> dict[str, Any] | None:
    state = service_state("nftables.service", timeout)
    if state is None:
        if host == "edge":
            return {
                "service": "missing",
                "config_valid": False,
                "blacklist_entries": None,
                "ipv4_forwarding": False,
            }
        return None
    check_rc, _ = run(["nft", "--check", "--file", "/etc/nftables.conf"], timeout)
    set_rc, raw = run(
        ["nft", "--json", "list", "set", "ip", "crowdsec", "crowdsec-blacklists"],
        timeout,
    )
    blacklist_entries = None
    if set_rc == 0:
        try:
            payload = json.loads(raw)
            entries = []
            for record in payload.get("nftables", []):
                definition = record.get("set", {})
                if definition.get("name") == "crowdsec-blacklists":
                    entries = definition.get("elem", [])
                    break
            blacklist_entries = len(entries)
        except (AttributeError, json.JSONDecodeError):
            pass
    forward_rc, forward = run(["sysctl", "-n", "net.ipv4.ip_forward"], timeout)
    return {
        "service": state,
        "config_valid": check_rc == 0,
        "blacklist_entries": blacklist_entries,
        "ipv4_forwarding": forward_rc == 0 and forward.strip() == "1",
    }


def collect(host: str, timeout: float) -> dict[str, Any]:
    containers = container_snapshot(host, timeout)
    exporters = []
    for unit in ("prometheus-node-exporter.service", "alloy.service"):
        state = service_state(unit, timeout)
        exporters.append(
            {"name": unit.removesuffix(".service"), "state": state or "missing"}
        )
    for item in containers["items"]:
        if "exporter" in item["name"]:
            exporters.append({"name": item["name"], "state": item["state"]})

    return {
        "containers": containers,
        "exporters": sorted(exporters, key=lambda item: item["name"]),
        "prometheus": prometheus_snapshot(host, containers, timeout),
        "caddy": caddy_snapshot(host, timeout),
        "minecraft": minecraft_snapshot(host, containers, timeout),
        "crowdsec": crowdsec_snapshot(host, timeout),
        "nftables": nftables_snapshot(host, timeout),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", required=True)
    parser.add_argument("--timeout", type=float, default=5.0)
    args = parser.parse_args()
    print(
        json.dumps(
            collect(args.host, max(0.1, args.timeout)),
            separators=(",", ":"),
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
