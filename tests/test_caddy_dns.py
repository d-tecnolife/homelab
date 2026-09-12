import pathlib
import re
import unittest

import yaml


ROOT = pathlib.Path(__file__).parents[1]


class CaddyDnsTests(unittest.TestCase):
    def test_every_caddy_site_has_a_managed_dns_record(self):
        # Hostnames drifted once already: four sites kept hand-made records that
        # pointed at Gateway instead of Door. Any site Caddy serves must be one
        # caddy.yml publishes, and vice versa.
        play = yaml.safe_load((ROOT / "ansible/playbooks/caddy.yml").read_text(encoding="utf-8"))[0]
        managed = set(play["vars"]["caddy_dns_names"])
        served = set()
        for site in (ROOT / "ansible/files/caddy/sites").glob("*.caddy"):
            match = re.search(r"^([a-z0-9.-]+\.dscim\.dev)\s*\{", site.read_text(encoding="utf-8"), re.MULTILINE)
            self.assertIsNotNone(match, f"{site.name} declares no dscim.dev site")
            served.add(match.group(1))
        self.assertEqual(managed, served)


if __name__ == "__main__":
    unittest.main()
