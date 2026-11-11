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
