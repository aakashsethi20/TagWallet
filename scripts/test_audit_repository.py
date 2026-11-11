import base64
import json
import unittest
from audit_repository import embedded_payload, private_path

class RepositoryAuditTests(unittest.TestCase):
    def test_rejects_actual_sized_nonzero_payloads(self):
        for length in (80, 532, 540):
            encoded = json.dumps({'data': base64.b64encode(bytes([7]) * length).decode()}).encode()
            self.assertTrue(embedded_payload(encoded))
    def test_permits_metadata_and_synthetic_fixtures(self):
        self.assertFalse(embedded_payload(b'{"dataKey": null, "tagProducts": []}'))
        self.assertFalse(embedded_payload(json.dumps({'data': base64.b64encode(bytes(80)).decode()}).encode()))
        self.assertFalse(embedded_payload(b'{"data": "invalid"}'))
    def test_staged_private_path_detection(self):
        for name in ('sample.BIN', 'test.tagwalletbackup', 'TagWalletUI/initialTagWallet.json', 'a/xcuserdata/test'):
            self.assertTrue(private_path(name))
        self.assertFalse(private_path('TagWalletUI/initialTagWallet.example.json'))

if __name__ == '__main__': unittest.main()
