#!/usr/bin/env python3
"""Build deterministic TagWallet catalogs; never print binary payloads."""
import argparse, base64, json, re
from pathlib import Path

SERIES = ['Series 1', 'Series 2', 'Series 3', 'Series 4', 'Series 5', 'Welcome Amiibo Series', 'Sanrio', 'Promos']
def encode(value): return base64.b64encode(value).decode('ascii')
def generate(source, images=None):
    wallet = {'schemaVersion': 1, 'tagProducts': []}
    for field, filename in [('dataKey', 'unfixed-info.bin'), ('staticKey', 'locked-secret.bin')]:
        data = (source / 'TagMo_Installer' / filename).read_bytes()
        if len(data) != 80 or data[31] > 16: raise ValueError(f'Invalid key: {filename}')
        wallet[field] = {'data': encode(data)}
    ids = set()
    for folder in SERIES:
        for path in sorted((source / folder).glob('*.bin')):
            raw = path.read_bytes()
            if len(raw) != 540: raise ValueError(f'Invalid dump length: {path.name}')
            match = re.fullmatch(r'\[AC\] (.+?) - (.+)', path.stem)
            if not match: raise ValueError(f'Unknown filename: {path.name}')
            number, character = match.groups()
            head, tail = raw[84:88].hex(), raw[88:92].hex()
            identity = head + tail
            if identity in ids: raise ValueError(f'Duplicate ID: {path.name}')
            ids.add(identity)
            product = dict(productSeries='Animal Crossing — ' + folder, character=character,
                           gameSeries='Animal Crossing', imageURL='', name=f'{number} - {character}',
                           type='Card', head=head, tail=tail, cardNumber=number,
                           imageAssetName=identity + '.png', dumps=[{'data': encode(raw[:532])}])
            wallet['tagProducts'].append(product)
    if images:
        wallet['images'] = {p.stem: encode(p.read_bytes()) for p in sorted(images.glob('*.png')) if p.stem in ids}
    return wallet

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--images', type=Path)
    parser.add_argument('--validate-only', action='store_true')
    args = parser.parse_args()
    wallet = generate(args.source, args.images)
    if not args.validate_only:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        temporary = args.output.with_suffix('.tmp')
        temporary.write_text(json.dumps(wallet, indent=2, ensure_ascii=False) + '\n')
        temporary.replace(args.output)
    print(f"Validated {len(wallet['tagProducts'])} unique cards and two keys.")
if __name__ == '__main__': main()
