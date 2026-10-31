"""Store-listing upload is one committed Play edit (run: python3 -m unittest discover -s .github/workflow-tests).

CM-055: upload_listing.py opens a single edit, applies the listing text and
every image to it, and commits it once, last, so a failed run leaves no
half-applied listing live. This job runs on system python3 without the Google
client libraries, so they are stubbed and the Play service is a mock.
"""

import importlib.util
import os
import pathlib
import sys
import types
import unittest
from unittest import mock

import yaml

REPO = pathlib.Path(__file__).resolve().parents[2]
STORE_LISTING = REPO / "store-listing"
SCREENSHOTS = STORE_LISTING / "screenshots"
EXPECTED_IMAGES = {
    "phoneScreenshots": [f"phone_{n}.png" for n in (1, 2, 3)],
    "sevenInchScreenshots": [f"tablet7_{n}.png" for n in (1, 2, 3)],
    "tenInchScreenshots": [f"tablet10_{n}.png" for n in (1, 2, 3)],
    "featureGraphic": ["feature_graphic.png"],
    "icon": ["icon.png"],
}
EDIT_CALLS = ("insert", "update", "deleteall", "upload", "commit")


class FakeHttpError(Exception):
    def __init__(self, status):
        super().__init__(status)
        self.resp = types.SimpleNamespace(status=status)
        self.reason = "stubbed"


def load_upload_listing():
    errors = types.ModuleType("googleapiclient.errors")
    errors.HttpError = FakeHttpError
    http = types.ModuleType("googleapiclient.http")
    http.MediaIoBaseUpload = lambda stream, mimetype: stream.getvalue()
    stubs = {
        "google": mock.MagicMock(),
        "google.oauth2": mock.MagicMock(),
        "googleapiclient": mock.MagicMock(),
        "googleapiclient.discovery": mock.MagicMock(),
        "googleapiclient.errors": errors,
        "googleapiclient.http": http,
    }
    spec = importlib.util.spec_from_file_location("upload_listing", STORE_LISTING / "upload_listing.py")
    module = importlib.util.module_from_spec(spec)
    with mock.patch.dict(sys.modules, stubs):
        spec.loader.exec_module(module)
    return module


class StoreListingSingleEdit(unittest.TestCase):
    def setUp(self):
        self.svc = mock.MagicMock()
        self.svc.edits().insert().execute.return_value = {"id": "edit-1"}
        self.svc.edits().commit().execute.return_value = {"id": "edit-1"}
        self.svc.reset_mock()

    def run_main(self):
        upload_listing = load_upload_listing()
        with mock.patch.dict(os.environ, {"PLAY_SERVICE_ACCOUNT_JSON": "{}"}), \
             mock.patch.object(upload_listing, "build", return_value=self.svc), \
             mock.patch("builtins.print"):
            upload_listing.main()
        return self.svc

    def edit_calls(self, svc):
        return [
            (name.rsplit(".", 1)[-1], kwargs)
            for name, _, kwargs in svc.mock_calls
            if name.rsplit(".", 1)[-1] in EDIT_CALLS
        ]

    def test_everything_lands_in_one_edit_committed_last(self):
        calls = self.edit_calls(self.run_main())
        self.assertEqual(calls[0][0], "insert")
        self.assertEqual(calls[-1][0], "commit")
        self.assertEqual([name for name, _ in calls].count("insert"), 1)
        self.assertEqual([name for name, _ in calls].count("commit"), 1)
        for name, kwargs in calls[1:]:
            with self.subTest(call=name, kwargs=kwargs.get("imageType")):
                self.assertEqual(kwargs["editId"], "edit-1")
                self.assertEqual(kwargs["packageName"], "net.interstellarai.cosmicmatch")
                if name != "commit":
                    self.assertEqual(kwargs["language"], "en-US")

    def test_listing_text_and_images_come_from_store_listing(self):
        calls = self.edit_calls(self.run_main())
        [listing] = [kwargs["body"] for name, kwargs in calls if name == "update"]
        for field, source in (("title", "title.txt"),
                              ("shortDescription", "short_description.txt"),
                              ("fullDescription", "full_description.txt")):
            with self.subTest(field=field):
                expected = (STORE_LISTING / "en-US" / source).read_text().strip()
                self.assertEqual(listing[field], expected)

        cleared = [kwargs["imageType"] for name, kwargs in calls if name == "deleteall"]
        self.assertCountEqual(cleared, EXPECTED_IMAGES)
        uploads = [(i, kwargs) for i, (name, kwargs) in enumerate(calls) if name == "upload"]
        last_clear = max(i for i, (name, _) in enumerate(calls) if name == "deleteall")
        self.assertGreater(uploads[0][0], last_clear)
        for img_type, files in EXPECTED_IMAGES.items():
            with self.subTest(imageType=img_type):
                uploaded = [kwargs["media_body"] for _, kwargs in uploads if kwargs["imageType"] == img_type]
                self.assertEqual(uploaded, [(SCREENSHOTS / f).read_bytes() for f in files])

    def test_workflow_is_dispatch_only_in_play_internal(self):
        workflow = yaml.safe_load((REPO / ".github/workflows/setup-store-listing.yml").read_text())
        # PyYAML reads the bare `on:` key as boolean True.
        self.assertEqual(list(workflow[True]), ["workflow_dispatch"])
        job = workflow["jobs"]["upload-listing"]
        self.assertEqual(job["environment"], "play-internal")
        self.assertEqual(job["permissions"], {"contents": "read"})
        self.assertEqual(job["steps"][-1]["run"], "python3 store-listing/upload_listing.py")

    def test_failed_run_never_commits(self):
        self.svc.edits().images().deleteall().execute.side_effect = FakeHttpError(403)
        self.svc.reset_mock()
        with self.assertRaises(RuntimeError):
            self.run_main()
        self.assertNotIn("commit", [name for name, _ in self.edit_calls(self.svc)])


if __name__ == "__main__":
    unittest.main()
