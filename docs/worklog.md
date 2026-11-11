# TagWallet worklog

## Branch and baseline
- Feature branch: feat/offline-library-christmas-batch.
- Working plan: implementation-plan.md (same directory).
- User verified the ten-card pilot writes and works on Switch.
- Pre-existing uncommitted changes: Xcode project/settings, ten-card initialTagWallet.json with keys, two-line detail-controller key handoff. Preserve these. Personal .DS_Store and Xcode xcuserdata must not be committed.

## Current progress
- Started model changes: mutable product metadata, optional cardNumber/imageAssetName, computed lowercase identity.
- Added validating Codable decoding for TagDump (532/540 accepted, normalized) and TagKey (80 bytes/layout).
- Drafted WalletStore.swift: snapshots, active/previous generation pointers, migration, merge, catalog import, image normalization, backup encoding. NOT yet registered in Xcode or built/tested.
- No UI/import picker/NFC progress integration yet. No full catalog generation yet.
- Consulted Apple UIKit document-picker guidance via Context7: asCopy import, coordinated/security-scoped reads.
- Attempted public GitHub revision download; inspect /private/tmp/amiibo-revision.json and curl session output before using. No artwork coverage established.

## Important review items before store integration
- Validate migration behavior on legacy invalid placeholder keys; current strict decode may reject entire old wallet.
- Ensure metadata override precedence does not freeze bundled metadata unintentionally.
- Store save currently validates/reencodes embedded images each mutation; review performance for full image catalog.
- Add recovery UI for corrupt active generation and a full backup restore entry point.
- Keep errors visible; don't claim persistence/write success when only one succeeded.

## Next actions
1. Register new source files; build and test store with synthetic fixtures.
2. Implement importer script and generate all 509 cards; fetch/validate artwork.
3. Implement shared-store-backed UI, Files import/export and sequential NFC workflow.
4. Add tests, build, inspect simulator UI, and document hardware-only checks.

## Checkpoints
- Documentation checkpoint: plan/worklog on new branch; code work remains unvalidated WIP.

## Implementation checkpoint (2026-11-10)
- Documentation checkpoint: 2a41e00.
- Generated 509 products and downloaded 509/509 matching offline PNGs at pinned revision 6115745c56ff762ce212ced6fbad9ea195d659b3; manifest records dimensions/URLs. No missing matches, so Nintendo fallback unnecessary.
- Added shared-store catalog grid, batch, detail actions, sequential writer, scan reader, Files BIN/catalog/key/image imports, backup/export/restore, and recovery screen.
- Model decoding validates binary lengths/key layout; legacy invalid key fields fall back to bundled keys.
- Registered new sources/resources and a shared XCTest scheme/target. Current project builds for the existing user-selected deployment target; tracked target minimum will be 17.0 for the new document-picker UI.
- First unsigned device build passed. First eight tests passed; expanded suite now passes 12 tests, including fake-writer cancellation/success and persistence retry without another write.
- Latest test result: /private/tmp/TagWallet-test-build/Logs/Test/Test-TagWallet-2026.11.10_22-22-00--0500.xcresult.
- Snapshot storage keeps logical user data/progress together in one atomic generation for transactional restores; images are embedded in snapshots for self-contained backup semantics.
- Remaining: simulator visual inspection, polish/review, generator tests, final device build and checkpoint. Physical NFC and Files-provider verification require user hardware; see device-checklist.md.

## Pause / model handoff — requested by user

User requested stopping at the next checkpoint to continue with a less expensive model. Do not resume implementation unless asked.

### Commits
- 2a41e00: shared implementation plan and worklog.
- d9aeabc: first feature checkpoint (offline catalog/artwork, store, UI, import/backup, writer, tests).
- The next checkpoint contains the final review fixes and this handoff; identify it with `git log -1`.

### Changes since d9aeabc
- Made generation-directory cleanup best effort so a cleanup error cannot remove an already-activated snapshot.
- Added actual imported-image preview, always-visible search, and normalization/type validation for catalog images.
- Added Python generator tests (4 passed).
- Expanded XCTest to include combined search/status/series filters and full 509-image backup coverage.

### Validation and artifacts
- Earlier unsigned iOS device build passed.
- Earlier simulator suite: 12 tests passed, including fake NFC success/cancellation and save retry without rewriting.
- Final expanded suite launched with log `/private/tmp/TagWallet-tests-final.log`; final outcome is appended below.
- Catalog and manifest validated at 509 unique cards / 509 matched PNGs. Image widths 230–630, heights 276–450 (source assets, not print-resolution claims).
- Simulator launched successfully; catalog screenshot `/private/tmp/tagwallet-catalog.png` visually verified as a two-column image grid with correct cards and navigation. This screenshot predates the always-visible-search polish.
- `git diff --check` passed before checkpoint.

### Exact resume priorities
1. Read implementation-plan.md and this log; inspect `git status` and latest commit before editing.
2. Review current implementation against the plan. Core flows exist, but don't equate passing unit tests with end-to-end readiness.
3. Verify simulator interactions for multi-selection, batch/skip/resume, image preview, import review, restore, dark mode and larger text. Only catalog screenshot was visually inspected.
4. Review UI/storage performance: snapshots embed images and validate them on mutations; large restored libraries may stall the main thread. Most bundled images are external resources until backup/restore. This deserves profiling/optimization.
5. Review remaining edge cases: interrupted import/restore, startup recovery, stale currentID, image cache invalidation, metadata precedence on future bundled updates, and failed progress-save navigation.
6. Run a final unsigned device build after review, then physical checklist with user hardware. No real NFC writes were performed by the agent; the user only verified the earlier pilot.
7. Keep committing coherent checkpoints and updating this log.

### Local state to preserve
- `TagWallet.xcodeproj/project.pbxproj` still has pre-existing personal signing/bundle/Xcode-warning settings unstaged. New feature registrations and iOS 17 minimum are committed; do not overwrite the user's remaining settings.
- Personal `.DS_Store` and Xcode `xcuserdata` are untracked and intentionally excluded.
- Python `scripts/__pycache__` is generated and excluded from commits.
- Simulator iPhone 17 (B598B072-A7C5-4E92-925E-8961B3F87C9A) was booted for visual inspection.
- No subagents were used. No push, deployment, or phone installation was performed.

### Final checkpoint results
- Expanded simulator suite PASSED: 14 tests, 0 failures (7.923 seconds test execution).
- Result bundle: /private/tmp/TagWallet-test-build/Logs/Test/Test-TagWallet-2026.11.10_22-25-45--0500.xcresult.
- Python generator suite PASSED: 4 tests.
- Implementation paused as requested; remaining review/device checks are listed above.

## Resumed review checkpoint (2026-11-10)
- Resumed from 05ff0c5 at the user's request; preserved personal project settings and generated/untracked files.
- Fixed migration precedence: matching legacy custom metadata now wins over bundled metadata, while bundle additions and distinct dumps still merge.
- Fixed failed next-position saves: keep the displayed card and do not start NFC when persistence fails.
- Progress-only saves skip normalization of unchanged validated images and retain cached artwork. Changed images remain validated; changed/removed image entries invalidate cache. Snapshot JSON still embeds/reencodes all images, so restored-library write latency remains a profiling item.
- Added regressions for matching legacy metadata, failed next-position persistence, and image cache retention/changed invalid image rejection.
- Validation: 17 XCTest tests passed (0 failures), 4 Python generator tests passed, final unsigned generic iOS build passed, git diff --check passed.
- Logs: /private/tmp/TagWallet-resume-tests.log and /private/tmp/TagWallet-resume-device.log.
- Simulator interactive inspection was attempted through the native UI tool, but both Simulator name and bundle identifier returned Invalid app. Multi-selection, batch/skip/resume, image review, import review/restore, dark mode, and larger-text visual checks remain unverified.
- Physical NFC/Files/Switch checks remain pending per device-checklist.md. No phone installation, NFC write, push, or deployment performed.
- Remaining review: future bundled metadata update policy, interrupted restore/recovery behavior, stale currentID handling (resume already falls back to remaining), and full-library snapshot latency. Do not treat this checkpoint as end-to-end acceptance.
