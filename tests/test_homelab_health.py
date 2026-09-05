import importlib.util
import json
import pathlib
import subprocess
import tempfile
import unittest
from unittest import mock


ROOT = pathlib.Path(__file__).parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


health = load("homelab_health", ROOT / "ansible/files/scripts/homelab-health.py")
probe = load("homelab_health_probe", ROOT / "ansible/files/scripts/homelab-health-probe.py")


class ResultTreeTests(unittest.TestCase):
    def test_invocation_timeout_preserves_partial_results(self):
        def time_out(command, **_kwargs):
            tree = pathlib.Path(command[command.index("--tree") + 1])
            snapshot = {
                "containers": {"engine": "active", "available": True, "items": []},
                "exporters": [],
            }
            (tree / "ops").write_text(
                json.dumps({"rc": 0, "stdout": json.dumps(snapshot)})
            )
            raise subprocess.TimeoutExpired(command, 30)

        with mock.patch.object(health.subprocess, "run", side_effect=time_out):
            rc, result = health.invoke_ansible(
                pathlib.Path("/tmp"),
                pathlib.Path("/tmp/inventory.yml"),
                pathlib.Path("/tmp/probe.py"),
                5,
            )

        self.assertEqual(rc, 124)
        self.assertTrue(result["ops"]["reachable"])

    def test_reads_success_and_redacts_unreachable_message(self):
        with tempfile.TemporaryDirectory() as directory:
            tree = pathlib.Path(directory)
            snapshot = {
                "containers": {"engine": "active", "available": True, "items": []},
                "exporters": [],
            }
            (tree / "ops").write_text(json.dumps({"rc": 0, "stdout": json.dumps(snapshot)}))
            (tree / "edge").write_text(
                json.dumps({"unreachable": True, "msg": "ssh failed with secret text"})
            )

            result = health.read_result_tree(tree)

        self.assertTrue(result["ops"]["reachable"])
        self.assertEqual(result["edge"], {"reachable": False, "reason": "unreachable"})
        self.assertNotIn("secret", json.dumps(result))

    def test_status_detects_down_prometheus_target(self):
        hosts = {
            "monitoring": {
                "reachable": True,
                "containers": {"engine": "active", "available": True, "items": []},
                "exporters": [],
                "prometheus": {
                    "reachable": True,
                    "targets": [{"job": "node", "instance": "edge:9100", "health": "down"}],
                },
            }
        }
        self.assertEqual(health.calculate_status(hosts, 0), "degraded")


class ProbeTests(unittest.TestCase):
    def test_container_output_keeps_only_selected_fields(self):
        docker_output = '"prometheus"\t"running"\t"Up 2 hours (healthy)"\n'
        with mock.patch.object(probe, "service_state", return_value="active"), mock.patch.object(
            probe, "run", return_value=(0, docker_output)
        ):
            result = probe.container_snapshot("monitoring", 5)
        self.assertEqual(
            result,
            {
                "available": True,
                "engine": "active",
                "items": [{"name": "prometheus", "state": "running", "health": "healthy"}],
            },
        )

    def test_prometheus_output_is_bounded_to_identity_and_health(self):
        containers = {
            "available": True,
            "engine": "active",
            "items": [{"name": "prometheus", "state": "running", "health": None}],
        }
        response = {
            "status": "success",
            "data": {
                "activeTargets": [
                    {
                        "labels": {"job": "node", "instance": "edge:9100", "secret": "omit"},
                        "health": "up",
                        "lastError": "omit",
                    }
                ]
            },
        }
        with mock.patch.object(probe, "http_json", return_value=response):
            result = probe.prometheus_snapshot("monitoring", containers, 5)
        self.assertEqual(
            result,
            {
                "container": "running",
                "reachable": True,
                "targets": [{"job": "node", "instance": "edge:9100", "health": "up"}],
            },
        )
        self.assertNotIn("secret", json.dumps(result))

    def test_expected_service_is_reported_missing(self):
        with mock.patch.object(probe, "service_state", return_value=None):
            result = probe.caddy_snapshot("edge", 5)
        self.assertEqual(result, {"service": "missing", "health_endpoint": False})


if __name__ == "__main__":
    unittest.main()
