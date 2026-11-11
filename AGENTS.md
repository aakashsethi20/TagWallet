# TagWallet agent instructions

## Start here

- Read this file and the **Current handoff summary** at the top of [docs/worklog.md](docs/worklog.md), then inspect `git status --short`, the current branch, and recent commits before editing.
- Use [README.md](README.md) for setup, [docs/import-guide.md](docs/import-guide.md) for user instructions, and [docs/file-formats.md](docs/file-formats.md) for import/storage formats.
- [docs/implementation-plan.md](docs/implementation-plan.md) contains the original scope plus amendments. [docs/checkpoint-ux-issues.md](docs/checkpoint-ux-issues.md) distinguishes reports, implemented fixes, and unverified behavior. Read completion entries before acting on historical TODOs or pause instructions.
- [docs/repository-publication-checkpoint.md](docs/repository-publication-checkpoint.md) records completed history sanitization and fork migration. Do not repeat that migration or resurrect private history.
- Preserve existing local edits, especially personal signing/bundle/deployment settings in `TagWallet.xcodeproj/project.pbxproj`. Do not commit Xcode userdata, caches, or `.DS_Store`.
- Do not spawn subagents unless the user explicitly authorizes delegation.

## Project and ownership

- Public home: https://github.com/aakashsethi20/TagWallet, default branch `main`.
- Original upstream: https://github.com/kevinbrewster/TagWallet. Preserve its MIT license, copyright, and README attribution.
- `origin` should point to the user's fork; `upstream` is for fetching the original. Check live remotes before a push; never push to the original upstream without explicit authorization.
- UIKit iOS app, iOS 17 minimum in the shared project. No cloud accounts/sync. Keep changes within the user's requested scope; avoid new dependencies without a concrete need.

## Code map

- `TagWalletUI/SceneDelegate.swift`: boots the shared store, Catalog/Batch/Library & Backup tabs, and recovery UI.
- `TagWalletUI/WalletStore.swift`: effective library, validated imports, metadata/dump merge, images/cache, generation-based persistence, named batches, backup encoding.
- `TagWalletUI/LibraryViewController.swift`: grid/cells, grouped draft filters, named list picker, card details, sequential writing UI, image preview.
- `TagWalletUI/ImportController.swift`: Files imports/review, keys, backup export/restore, scan import, recovery.
- `TagWalletUI/BatchWriter.swift` and `ScanReader.swift`: CoreNFC adapters. `CardWriting` allows fake-writer tests.
- `TagWallet/`: dump/key validation, cryptography, NTAG215 page writing. Preserve the established binary/crypto behavior; changes require focused regression evidence and device testing where applicable.
- `TagWalletUI/TagProductsCollectionViewController.swift` and `TagProductViewController.swift`: legacy storyboard UI, not the current main grid/detail flow. Verify call sites before fixing a visible issue there.
- `TagWalletTests/WalletStoreTests.swift`: synthetic fixtures, persistence/import/batch/writer/UI-state regressions, catalog/artwork coverage.
- `scripts/`: deterministic catalog generator, artwork fetcher, repository data audit, Python tests.

## Private-data boundary

- Bundle only tracked `TagWalletUI/initialTagWallet.example.json`: 509 metadata records, empty `dumps`, null keys. Artwork is separate. Do not put working keys or real dumps in the example, test fixtures, logs, screenshots, docs, commits, or PRs.
- Users supply their own dumps/keys via Files imports. An ignored `initialTagWallet.json` may exist locally, but is not bundled automatically. Do not delete or publish it.
- Generator source: https://github.com/miffycs/Animal-Crossing-Amiibo. Use an ignored checkout under `private/Animal-Crossing-Amiibo` and write generated private catalogs under `private/`. Do not assume any user's home directory or an adjacent checkout exists.
- Raw BIN/key/dump files, backups, local/key JSON, private inputs, and personal/generated files are ignored. Ignore rules do not protect already tracked files or arbitrary renamed JSON; inspect staged content.
- Tests use synthetic keys/dumps. History/staged audits are targeted checks, not a guarantee against every credential or encoding.
- Never merge/push pre-sanitization feature branches, tags, stashes, or backup refs. Old private history is intentionally outside the publishable repository.
- URL import is not implemented. Current instructions are download to Files, then import. Do not document proposed functionality as available.

## Behavior to preserve

- Identity is lowercase `head + tail`; validate dump identity and lengths. Imports merge distinct dumps, skip duplicates, retain absent cards and completion history. Metadata/image replacement and imported keys require explicit choices.
- Multiple named batches coexist. Add uses the remembered active list directly; a single list needs no repeated selection. Membership and resume position belong to each list; completion and Switch-tested history are shared globally. Rename/delete UI is not implemented.
- `savedBatches`/`activeBatchID` store lists; existing `progress.batch`/`currentID` project the active list. Keep them synchronized through store APIs. Older snapshots/backups migrate to one list.
- Removing/readding membership preserves completion. Undoing completion clears Switch-tested. Resume tolerates a stale position by choosing a remaining card.
- Stage and validate a complete generation before atomically switching its active pointer. Preserve recovery data; do not silently reset a corrupt library. Backup restore replaces library/progress together after validation/confirmation. Catalog import does not restore progress.
- Mark completion only after successful NFC writing. If persistence fails after writing, clearly report “tag written; progress not saved” and retry persistence without another NFC write. Failed position saves must not navigate/start writing. Lock selection-changing navigation during writes/unsaved completion.
- Filter changes are drafts until Apply; Cancel/swipe dismissal discards them. Show all clears filters and search. Preserve grid cells/selection for unchanged ordering; avoid whole-catalog sorting, artwork decoding, and animated badge churn on each membership change.
- Snapshot JSON still embeds images and encodes synchronously. If restored-library mutations stall, profile this path rather than assuming sorting is the only cause.

## Validation

For documentation-only changes, check links/commands and `git diff --check`; no app rebuild is needed. For source changes, run focused regressions and the applicable build/tests. From the repository root:

```bash
python3 -m unittest discover -s scripts -p 'test_*.py'
xcrun simctl list devices available
xcodebuild test -project TagWallet.xcodeproj -scheme TagWallet \
  -destination 'platform=iOS Simulator,id=<AVAILABLE_SIMULATOR_UDID>' \
  -derivedDataPath /tmp/TagWallet-tests CODE_SIGNING_ALLOWED=NO
xcodebuild build -project TagWallet.xcodeproj -scheme TagWallet \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/TagWallet-device CODE_SIGNING_ALLOWED=NO
git diff --check
```

Replace the simulator placeholder with an available device; do not hardcode a previous session's UDID or result path. Xcode may require access to caches/CoreSimulator outside a sandbox. Report tool/access failures accurately.

Before committing, stage only intended files and run:

```bash
python3 scripts/audit_repository.py --staged
```

Before publishing, also run:

```bash
python3 scripts/audit_repository.py
```

CI runs the history audit with a full fetch. At the publication checkpoint, 22 XCTest tests, seven Python tests, and an unsigned device build passed; verify current results rather than treating these counts as permanently current.

Real NFC, locked-tag/cancellation behavior, Files-provider export/restore, and Switch compatibility require hardware verification. See [docs/device-checklist.md](docs/device-checklist.md). The user reports the UX is improved and plans to test NFC later; do not mark NFC acceptance complete based on fake-writer tests. Native simulator UI access has been unavailable in prior sessions; report what was actually inspected.

## Working and documentation conventions

- Use `rg` for searches and Conventional Commits: `<type>[optional scope]: <description>`. If an issue ID exists, start the description with it.
- Use Context7 for targeted library/API documentation; prefer authoritative upstream sources. For recency-dependent claims, establish and state current ISO date/time. Cross-check compatibility/safety-sensitive claims against authoritative sources.
- Use repository-relative paths and upstream links in public instructions. Historical temporary log paths are evidence only, never setup requirements. Never add personal home-directory paths to public guides.
- Update `docs/worklog.md` at coherent checkpoints with completed changes, actual validation, remaining work, and limitations. Keep its current summary accurate. Label historical plans/reports clearly and distinguish implemented work from unverified device acceptance.
- Keep docs-only work separate from unrelated code/settings changes. Do not claim a fix eliminates every framework warning without reproducing/correlating it.
