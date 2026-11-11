import base64
import json
import tempfile
import unittest
from pathlib import Path
from import_catalog import generate, SERIES

class ImportTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.root = Path(self.tmp.name)
        for folder in SERIES + ['TagMo_Installer']: (self.root / folder).mkdir()
        for filename in ['unfixed-info.bin', 'locked-secret.bin']:
            (self.root / 'TagMo_Installer' / filename).write_bytes(bytes(80))
        self.raw = bytearray(540); self.raw[84] = 1
        (self.root / 'Series 1' / '[AC] 001 - Test.bin').write_bytes(self.raw)
    def tearDown(self): self.tmp.cleanup()
    def test_deterministic_normalization(self):
        first = generate(self.root); second = generate(self.root)
        self.assertEqual(first, second)
        p = first['tagProducts'][0]
        self.assertEqual(base64.b64decode(p['dumps'][0]['data']), self.raw[:532])
        self.assertEqual(p['head'], '01000000')
        self.assertEqual(len(base64.b64decode(first['dataKey']['data'])), 80)
    def test_duplicate_rejected(self):
        (self.root / 'Series 2' / '[AC] 101 - Duplicate.bin').write_bytes(self.raw)
        with self.assertRaises(ValueError): generate(self.root)
    def test_bad_key_and_dump_rejected(self):
        (self.root / 'Series 1' / '[AC] 001 - Test.bin').write_bytes(bytes(20))
        with self.assertRaises(ValueError): generate(self.root)
        (self.root / 'TagMo_Installer' / 'unfixed-info.bin').write_bytes(bytes(79))
        with self.assertRaises(ValueError): generate(self.root)
    def test_full_repository_catalog(self):
        path = Path(__file__).resolve().parents[1] / 'TagWalletUI/initialTagWallet.json'
        catalog = json.loads(path.read_text()); cards = catalog['tagProducts']
        self.assertEqual(len(cards), 509)
        self.assertEqual(len({p['head'] + p['tail'] for p in cards}), 509)
        for p in cards:
            raw = base64.b64decode(p['dumps'][0]['data'], validate=True)
            self.assertEqual(len(raw), 532)
            self.assertEqual(raw[84:92].hex(), p['head'] + p['tail'])
        manifest = json.loads((path.parent / 'CardImages/manifest.json').read_text())
        self.assertEqual(len(manifest), 509)
        self.assertTrue(all('filename' in item for item in manifest))

if __name__ == '__main__': unittest.main()
