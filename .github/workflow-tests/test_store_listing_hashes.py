"""Hash-checked install in the store-listing job (run: python3 -m unittest discover -s .github/workflow-tests).

setup-store-listing.yml holds PLAY_SERVICE_ACCOUNT_JSON, so its pip install
must run in hash mode: every direct and transitive package has to match a hash
recorded in store-listing/requirements.txt (SEC-18, #321).
"""

import pathlib
import unittest

import yaml

WORKFLOWS = pathlib.Path(__file__).resolve().parents[1] / "workflows"


class StoreListingHashes(unittest.TestCase):
    def test_every_pip_install_requires_hashes(self):
        steps = yaml.safe_load((WORKFLOWS / "setup-store-listing.yml").read_text())["jobs"]["upload-listing"]["steps"]
        installs = [line.split() for s in steps for line in s.get("run", "").splitlines() if "pip install" in line]
        self.assertTrue(installs)
        for install in installs:
            with self.subTest(install=" ".join(install)):
                self.assertIn("--require-hashes", install)


if __name__ == "__main__":
    unittest.main()
