#!/usr/bin/env python3
"""Fetch ID-matched public card images at an explicit repository revision."""
import argparse, concurrent.futures, json, struct, urllib.request
from pathlib import Path

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--revision', required=True)
    p.add_argument('--catalog', type=Path, default=Path('TagWalletUI/initialTagWallet.json'))
    p.add_argument('--output', type=Path, default=Path('TagWalletUI/CardImages'))
    a = p.parse_args(); a.output.mkdir(parents=True, exist_ok=True)
    products = json.loads(a.catalog.read_text())['tagProducts']
    def fetch(card):
        identity = card['head'] + card['tail']
        url = f"https://raw.githubusercontent.com/N3evin/AmiiboAPI/{a.revision}/images/icon_{card['head']}-{card['tail']}.png"
        entry = {'id': identity, 'url': url, 'revision': a.revision}
        try:
            path = a.output / (identity + '.png')
            raw = path.read_bytes() if path.exists() else urllib.request.urlopen(url, timeout=30).read()
            if raw[:8] != b'\x89PNG\r\n\x1a\n': raise ValueError('Not a PNG')
            entry['width'], entry['height'] = struct.unpack('>II', raw[16:24])
            path.write_bytes(raw); entry['filename'] = path.name
        except Exception as e: entry['error'] = str(e)
        return entry
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool: entries = list(pool.map(fetch, products))
    (a.output / 'manifest.json').write_text(json.dumps(entries, indent=2) + '\n')
    print(f"Artwork: {sum('filename' in x for x in entries)}/{len(entries)} matched")
if __name__ == '__main__': main()
