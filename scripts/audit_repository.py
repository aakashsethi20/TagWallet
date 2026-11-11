#!/usr/bin/env python3
"""Reject embedded key/dump payloads and private paths in reachable history.

Prints object IDs/pathnames only, never payloads. This targeted audit is not a
replacement for reviewing other credentials or renamed/non-JSON data files.
"""
import argparse
import base64
import re
import subprocess
from pathlib import PurePosixPath

PAYLOAD = re.compile(rb'"data"\s*:\s*"([A-Za-z0-9+/=]+)"')

def private_path(path):
    name = PurePosixPath(path)
    return (name.suffix.lower() in {'.bin', '.key', '.dump', '.tagwalletbackup'} or
            'xcuserdata' in name.parts or
            path in {'TagWalletUI/initialTagWallet.json', 'TagWalletUI/tagWallet.json'})

def embedded_payload(data):
    for value in PAYLOAD.findall(data):
        try:
            raw = base64.b64decode(value, validate=True)
        except ValueError:
            continue
        # Synthetic all-zero fixtures are permitted, retail/card content is not.
        if len(raw) in {80, 532, 540} and any(raw):
            return True
    return False

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--staged', action='store_true', help='Check staged files instead of reachable history')
    args = parser.parse_args()
    issues = []; count = 0
    if args.staged:
        paths = subprocess.check_output(['git', 'diff', '--cached', '--name-only', '--diff-filter=ACMR', '-z']).split(b'\0')
        for raw_path in filter(None, paths):
            path = raw_path.decode()
            data = subprocess.check_output(['git', 'show', ':' + path])
            count += 1
            if private_path(path) or embedded_payload(data): issues.append(path)
    else:
        rows = subprocess.check_output(['git', 'rev-list', '--objects', '--all']).splitlines()
        objects = {}
        for row in rows:
            oid, _, path = row.partition(b' ')
            objects[oid.decode()] = path.decode(errors='replace')
        process = subprocess.Popen(['git', 'cat-file', '--batch'], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        try:
            for oid, path in objects.items():
                process.stdin.write((oid + '\n').encode()); process.stdin.flush()
                header = process.stdout.readline().split()
                size = int(header[2]); data = process.stdout.read(size); process.stdout.read(1)
                if header[1] != b'blob': continue
                count += 1
                # Original upstream commits contain placeholder catalog JSON and public
                # Xcode scheme metadata. Retain that ancestry, reject real payloads.
                if PurePosixPath(path).suffix.lower() in {'.bin', '.key', '.dump', '.tagwalletbackup'} or embedded_payload(data):
                    issues.append(oid + ' ' + path)
        finally:
            process.stdin.close(); process.stdout.close(); process.wait()
    for issue in issues: print('REJECT:', issue)
    print(f'Checked {count} blobs/files; {len(issues)} potential private-data violations.')
    return bool(issues)

if __name__ == '__main__':
    raise SystemExit(main())
