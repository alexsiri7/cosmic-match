"""Deploy gates in ci.yml (run: python3 -m unittest discover -s .github/workflow-tests).

ci.yml accepts workflow_dispatch (the factory build-drift check dispatches it
on main), and a dispatched run has the same github.ref as a push. Any job or
step keyed on github.ref must therefore also require a push, or a dispatch
would publish to the Play Store / cut a release / notify prod (#271).

Play publishing runs only in jobs bound to a GitHub Environment, so the Play
secret is environment-scoped and production waits for a reviewer (SEC-07,
#310). The `release` job, which runs on every PR, must never take one.
"""
import pathlib
import unittest

import yaml

WORKFLOWS = pathlib.Path(__file__).resolve().parents[1] / "workflows"
CI = WORKFLOWS / "ci.yml"
PLAY_SECRET_WORKFLOWS = sorted(WORKFLOWS.glob("*.yml"))
PUSH_ONLY = "github.event_name == 'push'"


def top_level_conjuncts(expr):
    """Split an Actions `if:` expression on `&&` outside parentheses."""
    parts, depth, start = [], 0, 0
    for i, ch in enumerate(expr):
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        elif depth == 0 and expr.startswith("&&", i):
            parts.append(expr[start:i])
            start = i + 2
    parts.append(expr[start:])
    return [p.strip() for p in parts]


def ci_jobs():
    return yaml.safe_load(CI.read_text())["jobs"]


def ref_gated_conditions():
    """Every job- and step-level `if:` in ci.yml that mentions github.ref."""
    gated = {}
    for job_id, job in ci_jobs().items():
        if "github.ref" in str(job.get("if", "")):
            gated[(job_id, None)] = job["if"]
        for step in job.get("steps", []):
            if "github.ref" in str(step.get("if", "")):
                gated[(job_id, step["name"])] = step["if"]
    return gated


class ReleaseGate(unittest.TestCase):
    def test_ci_is_dispatchable(self):
        # PyYAML reads the bare `on:` key as boolean True.
        self.assertIn("workflow_dispatch", yaml.safe_load(CI.read_text())[True])

    def test_every_ref_gated_condition_requires_push(self):
        for (job_id, step), cond in ref_gated_conditions().items():
            with self.subTest(job=job_id, step=step):
                self.assertIn(PUSH_ONLY, top_level_conjuncts(cond))

    def test_known_deploy_steps_are_ref_gated(self):
        self.assertLessEqual({
            ("publish-internal", None),
            ("publish-internal", "Publish to Play Store internal track (non-tag)"),
            ("publish-internal", "Notify prod landing"),
            ("publish-production", None),
            ("publish-production", "Publish to Play Store production (tag release)"),
            ("publish-production", "Create GitHub Release (tag pushes only)"),
            ("publish-production", "Notify prod landing"),
        }, ref_gated_conditions().keys())

    def test_play_secret_only_in_environment_jobs(self):
        for path in PLAY_SECRET_WORKFLOWS:
            for job_id, job in yaml.safe_load(path.read_text())["jobs"].items():
                if "secrets.PLAY_SERVICE_ACCOUNT_JSON" in str(job):
                    with self.subTest(workflow=path.name, job=job_id):
                        self.assertIn("environment", job)

    def test_production_publish_is_environment_gated(self):
        jobs = ci_jobs()
        self.assertEqual(jobs["publish-production"]["environment"], "production")
        homes = [
            job_id for job_id, job in jobs.items()
            for step in job.get("steps", [])
            if step.get("name") == "Publish to Play Store production (tag release)"
        ]
        self.assertEqual(homes, ["publish-production"])

    def test_publish_uploads(self):
        def step(job_id, name):
            [found] = [s for s in ci_jobs()[job_id]["steps"] if s.get("name") == name]
            return found["with"]

        internal = step("publish-internal", "Publish to Play Store internal track (non-tag)")
        self.assertEqual((internal["track"], internal["status"]), ("internal", "draft"))
        production = step("publish-production", "Publish to Play Store production (tag release)")
        self.assertEqual(production["track"], "production")
        self.assertEqual(production["mappingFile"], "dist/mapping.txt")
        release = step("publish-production", "Create GitHub Release (tag pushes only)")
        self.assertEqual(
            release["files"].split(), ["dist/app-release.aab", "dist/app-release.apk"]
        )

    def test_release_job_has_no_environment(self):
        self.assertNotIn("environment", ci_jobs()["release"])

    def test_job_permissions_are_least_privilege(self):
        # contents: write (cutting a GitHub Release) lives only behind the
        # reviewer-gated production environment.
        jobs = ci_jobs()
        self.assertEqual(jobs["release"]["permissions"], {"contents": "read"})
        self.assertNotIn("permissions", jobs["publish-internal"])
        self.assertEqual(jobs["publish-production"]["permissions"], {"contents": "write"})

    def test_conjunct_split_respects_parentheses(self):
        self.assertEqual(
            top_level_conjuncts("a && (b || c && d) && e"),
            ["a", "(b || c && d)", "e"],
        )


if __name__ == "__main__":
    unittest.main()
