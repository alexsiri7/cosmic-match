"""Lockfile enforcement in CI (run: python3 -m unittest discover -s .github/workflow-tests).

Every job that sets up Flutter must resolve packages with
`flutter pub get --enforce-lockfile` before any other flutter command, so a
stale or hand-edited pubspec.lock fails CI instead of drifting (#319). A plain
`flutter analyze`/`test`/`build` would otherwise run an implicit, unenforced
pub get.
"""

import pathlib
import unittest

import yaml

WORKFLOWS = pathlib.Path(__file__).resolve().parents[1] / "workflows"
ENFORCED = "flutter pub get --enforce-lockfile"


def flutter_jobs():
    for path in sorted(WORKFLOWS.glob("*.yml")):
        for job_id, job in yaml.safe_load(path.read_text())["jobs"].items():
            steps = job.get("steps", [])
            if any("flutter-action" in s.get("uses", "") for s in steps):
                yield f"{path.name}:{job_id}", steps


def flutter_commands(steps):
    for step in steps:
        script = step.get("run", "") + step.get("with", {}).get("script", "")
        for line in script.splitlines():
            line = line.strip()
            if line.startswith("flutter "):
                yield line


class LockfileEnforced(unittest.TestCase):
    def test_flutter_jobs_exist(self):
        self.assertTrue(list(flutter_jobs()))

    def test_first_flutter_command_is_enforced_pub_get(self):
        for name, steps in flutter_jobs():
            with self.subTest(job=name):
                commands = list(flutter_commands(steps))
                self.assertTrue(commands)
                self.assertEqual(commands[0], ENFORCED)

    def test_every_pub_get_enforces_lockfile(self):
        for name, steps in flutter_jobs():
            for command in flutter_commands(steps):
                if command.startswith("flutter pub get"):
                    with self.subTest(job=name, command=command):
                        self.assertEqual(command, ENFORCED)


if __name__ == "__main__":
    unittest.main()
