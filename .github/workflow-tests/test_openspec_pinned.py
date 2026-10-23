"""OpenSpec CLI pin in openspec.yml (run: python3 -m unittest discover -s .github/workflow-tests).

The validate job once ran `npx -y @fission-ai/openspec@latest`, executing
whatever version was last published with no integrity check (#318). It now
installs the CLI from .github/openspec/package-lock.json with `npm ci`, and
Dependabot keeps that lockfile on the latest release (#270).
"""

import json
import pathlib
import re
import unittest

import yaml

GITHUB = pathlib.Path(__file__).resolve().parents[1]
WORKFLOW = GITHUB / "workflows" / "openspec.yml"
TOOL_DIR = GITHUB / "openspec"
PACKAGE = "@fission-ai/openspec"


def validate_steps():
    workflow = yaml.safe_load(WORKFLOW.read_text())
    return workflow["jobs"]["validate"]["steps"]


def pinned_version():
    manifest = json.loads((TOOL_DIR / "package.json").read_text())
    return manifest["devDependencies"][PACKAGE]


class OpenSpecPinned(unittest.TestCase):
    def test_no_unpinned_npx(self):
        for step in validate_steps():
            run = step.get("run", "")
            self.assertNotIn("npx", run)
            self.assertNotIn("@latest", run)

    def test_installs_from_lockfile(self):
        self.assertTrue(
            any(
                step.get("run", "").startswith("npm ci")
                and step.get("working-directory") == ".github/openspec"
                for step in validate_steps()
            )
        )

    def test_manifest_pins_exact_version(self):
        self.assertRegex(pinned_version(), r"^\d+\.\d+\.\d+$")

    def test_lockfile_matches_manifest_with_integrity(self):
        lock = json.loads((TOOL_DIR / "package-lock.json").read_text())
        entry = lock["packages"][f"node_modules/{PACKAGE}"]
        self.assertEqual(entry["version"], pinned_version())
        self.assertTrue(re.match(r"^sha512-.+", entry.get("integrity", "")))

    def test_dependabot_tracks_the_pin(self):
        dependabot = yaml.safe_load((GITHUB / "dependabot.yml").read_text())
        self.assertIn(
            ("npm", "/.github/openspec"),
            [(u["package-ecosystem"], u["directory"]) for u in dependabot["updates"]],
        )


if __name__ == "__main__":
    unittest.main()
