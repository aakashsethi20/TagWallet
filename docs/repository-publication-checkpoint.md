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

## Completed publication / local migration

- Public GitHub-linked fork: https://github.com/aakashsethi20/TagWallet (parent: kevinbrewster/TagWallet).
- Default branch: `main`. Sanitized source preparation commit: `62d88c9`. Rewritten feature commit IDs differ from the historical private-checkpoint IDs in older documents.
- Published only the sanitized main branch. No original private feature branch, backup refs, or stashes were pushed. Original upstream ancestry remains available for attribution.
- GitHub Actions private-data audit passed: https://github.com/aakashsethi20/TagWallet/actions/runs/42958205455.
- Current workspace switched to sanitized history; origin now points to the user's fork. The original repo is retained as fetch-only upstream, with pushes disabled locally.
- Original private Git directory retained outside the repository at `/private/tmp/TagWallet-original-private.git` for rollback. It contains private history and must never be pushed. This temporary backup is not a durable archive.
- Local ignored catalog left on disk; personal project settings reapplied and remain uncommitted. No private catalog resource is bundled by the new project configuration.
- Validation: 22 XCTest tests passed with example-only catalog; seven Python tests passed; unsigned generic iOS build passed. Reachable sanitized history audit after preparation commit: 616 blobs, zero detected violations.

Do not push any old private-history branch or backup ref into this fork.

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
