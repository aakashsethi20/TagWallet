# Repository publication checkpoint

## Completed preparation

- Source checkpoint: `91dfdd1` in the private development checkout.
- Original project: https://github.com/kevinbrewster/TagWallet. Kevin Brewster's MIT license/copyright and upstream commit ancestry are retained. README prominently credits the original author.
- Audited original upstream ancestry: no nonzero decoded 80/532/540-byte key/dump payloads found. Upstream has placeholder configuration JSON, not working keys/dumps.
- Rewrote only post-upstream feature commits to remove `TagWalletUI/initialTagWallet.json`, historical `TagWalletUI/tagWallet.json` if present, and personal Xcode scheme data from those commits. Private inputs never need to be published to create a GitHub-linked fork.
- Scanned reachable candidate history: zero detected private-data violations. The audit checks binary/key/backup paths and nonzero key/dump-sized Base64 `data` fields. This is targeted validation, not proof against every possible encoding/credential type.
- Added ignored private inputs and a tracked metadata-only `initialTagWallet.example.json`: 509 cards, empty dump arrays, null keys. It supports catalog browsing and artwork without private data.
- Changed the build to bundle only the example. A local ignored `initialTagWallet.json` is not included automatically; import private data through Files.
- Candidate source passed 22 XCTest tests using only the example and synthetic key/dump fixtures. Python generator tests passed. No private catalog is needed to build/test.
- Added staged/history audit commands and a CI history-audit workflow. Review renamed JSON and other secrets manually too.

## Publication / local migration status

Prepared for public GitHub-linked fork under `aakashsethi20/TagWallet`. Publication and current-workspace remote/history migration are pending until recorded below. No private-history branch or backup ref may be pushed.

## Private inputs and continuing development

Store generated private catalogs under ignored `private/`; `.bin`, `.key`, `.dump`, `.tagwalletbackup`, legacy wallet JSON, local JSON, key JSON, Xcode userdata, and Python caches are ignored. Ignore rules apply to untracked files; they cannot remove data from an existing tracked file or history.

Before committing:

```bash
python3 scripts/audit_repository.py --staged
```

Before publishing branches:

```bash
python3 scripts/audit_repository.py
```

Tests use synthetic fixtures. CI scans reachable history with a full fetch. Do not push old private development branches, tags, stashes, or backup refs into this fork. Original private history, if retained locally for rollback, must stay outside the publishable repository.

## Still pending product/device work

- URL import is not implemented. Download files to Files first, then use BIN/catalog/key import.
- Phone visual verification and real NFC/Files/Switch checks remain as recorded in the UX report/device checklist.
- Existing installed app data is retained with the same bundle identifier; export an external private backup before uninstalling or changing identifiers.
