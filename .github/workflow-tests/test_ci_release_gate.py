"""Release-job deploy gate in ci.yml (run: python3 -m unittest discover -s .github/workflow-tests).

ci.yml accepts workflow_dispatch (the factory build-drift check dispatches it
on main), and a dispatched run has the same github.ref as a push. Any release
step keyed on github.ref must therefore also require a push, or a dispatch
would publish to the Play Store / cut a release / notify prod (#271).
"""

import pathlib
import unittest

import yaml

CI = pathlib.Path(__file__).resolve().parents[1] / "workflows" / "ci.yml"
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


def ref_gated_release_steps():
    workflow = yaml.safe_load(CI.read_text())
    steps = workflow["jobs"]["release"]["steps"]
    return {s["name"]: s["if"] for s in steps if "github.ref" in str(s.get("if", ""))}


class ReleaseGate(unittest.TestCase):
    def test_ci_is_dispatchable(self):
        # PyYAML reads the bare `on:` key as boolean True.
        self.assertIn("workflow_dispatch", yaml.safe_load(CI.read_text())[True])

    def test_every_ref_gated_release_step_requires_push(self):
        for name, cond in ref_gated_release_steps().items():
            with self.subTest(step=name):
                self.assertIn(PUSH_ONLY, top_level_conjuncts(cond))

    def test_known_deploy_steps_are_ref_gated(self):
        self.assertLessEqual({
            "Publish to Play Store internal track (non-tag)",
            "Publish to Play Store production (tag release)",
            "Create GitHub Release (tag pushes only)",
            "Notify prod landing",
        }, ref_gated_release_steps().keys())

    def test_conjunct_split_respects_parentheses(self):
        self.assertEqual(
            top_level_conjuncts("a && (b || c && d) && e"),
            ["a", "(b || c && d)", "e"],
        )


if __name__ == "__main__":
    unittest.main()
