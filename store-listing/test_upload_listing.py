"""Run with: python3 -m unittest discover store-listing (needs requirements.txt installed)."""

import json, os, traceback, unittest
from unittest import mock

import httplib2
from googleapiclient.errors import HttpError

import upload_listing

MARKER = 'SECRET-MARKER'


def http_error(status):
    body = json.dumps({'error': {
        'code': status,
        'message': 'The caller does not have permission',
        'details': [{'reason': MARKER}],
    }}).encode()
    return HttpError(httplib2.Response({'status': status}), body,
                     uri=f'https://androidpublisher.googleapis.com/{MARKER}')


class ImageCleanupTest(unittest.TestCase):
    def run_main(self, deleteall_status):
        svc = mock.MagicMock()
        svc.edits().insert().execute.return_value = {'id': 'edit-1'}
        svc.edits().images().deleteall().execute.side_effect = http_error(deleteall_status)
        with mock.patch.dict(os.environ, {'PLAY_SERVICE_ACCOUNT_JSON': '{}'}), \
             mock.patch.object(upload_listing, 'service_account'), \
             mock.patch.object(upload_listing, 'build', return_value=svc), \
             mock.patch.object(upload_listing, 'upload_image'), \
             mock.patch('builtins.print') as printed:
            try:
                upload_listing.main()
            finally:
                self.output = ' '.join(str(c) for c in printed.call_args_list)
        return svc

    def test_non_404_fails_without_leaking_the_raw_error(self):
        with self.assertRaises(RuntimeError) as caught:
            self.run_main(403)
        rendered = ''.join(traceback.format_exception(caught.exception))
        self.assertIn('HTTP 403 (The caller does not have permission)', rendered)
        self.assertNotIn(MARKER, rendered)
        self.assertNotIn(MARKER, self.output)

    def test_404_is_logged_without_the_raw_error_and_upload_continues(self):
        svc = self.run_main(404)
        self.assertIn('No existing icon: HTTP 404', self.output)
        self.assertNotIn(MARKER, self.output)
        svc.edits().commit.assert_called()


if __name__ == '__main__':
    unittest.main()
