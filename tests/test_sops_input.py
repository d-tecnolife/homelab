"""Exercise shared input tasks with a fake SOPS executable and synthetic data only."""
import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[1]
TASKS = ROOT / "ansible/playbooks/tasks"
MARKER = "synthetic-credential-must-not-appear"


@unittest.skipUnless(shutil.which("ansible-playbook") and os.name == "posix", "requires Ansible on Linux")
class SopsInputTests(unittest.TestCase):
    def run_fixture(self, *, check=False, missing=False, incomplete=False):
        with tempfile.TemporaryDirectory() as directory:
            fixture = pathlib.Path(directory)
            input_file = fixture / "input.env"
            if not missing:
                input_file.write_text("synthetic input; never encrypted")
            fake_sops = fixture / "sops"
            # No real SOPS command is invoked; this executable returns only
            # fixed dummy values and verifies the caller's environment override.
            fake_sops.write_text("#!/bin/sh\n"
                                 'test "$SOPS_AGE_KEY_FILE" = fixture-only || exit 9\n'
                                 'test "$1" = decrypt || exit 10\n'
                                 'test -f "$2" || exit 11\n'
                                 "printf 'OPNSENSE_URL=https://example.invalid\\nOPNSENSE_API_KEY=" + MARKER + "\\n'\n"
                                 + ("" if incomplete else "printf 'OPNSENSE_API_SECRET=" + MARKER + "\\n'\n"))
            fake_sops.chmod(0o700)
            playbook = fixture / "test.yml"
            playbook.write_text(yaml.safe_dump([{
                "hosts": "localhost", "gather_facts": False, "become": True,
                "vars": {"sops_input_path": str(input_file),
                         "sops_input_missing_message": "fixture input missing",
                         "sops_input_environment": {"SOPS_AGE_KEY_FILE": "fixture-only"}},
                "tasks": [
                    {"ansible.builtin.import_tasks": str(TASKS / "load-sops-input.yml")},
                    {"ansible.builtin.import_tasks": str(TASKS / "gateway-credentials.yml")},
                    {"ansible.builtin.assert": {"that": ["gateway_url == 'https://example.invalid'", "gateway_api_key | length > 0", "gateway_api_secret | length > 0"]}}
                ]}], sort_keys=False))
            result = subprocess.run(
                ["ansible-playbook", "-i", "localhost,", "-c", "local", str(playbook)] + (["--check"] if check else []),
                cwd=ROOT / "ansible", env=os.environ | {"PATH": str(fixture) + os.pathsep + os.environ["PATH"], "ANSIBLE_NOCOLOR": "1"},
                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
            self.assertNotIn(MARKER, result.stdout)
            return result

    def test_loads_in_normal_and_check_mode_without_privilege_or_secret_output(self):
        for check in [False, True]:
            with self.subTest(check=check):
                result = self.run_fixture(check=check)
                self.assertEqual(result.returncode, 0, result.stdout)
                self.assertIn("changed=0", result.stdout)

    def test_missing_input_fails_before_loading(self):
        result = self.run_fixture(missing=True, check=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fixture input missing", result.stdout)

    def test_incomplete_gateway_values_fail_without_credential_output(self):
        result = self.run_fixture(incomplete=True, check=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Require complete Gateway API values", result.stdout)


if __name__ == "__main__":
    unittest.main()
