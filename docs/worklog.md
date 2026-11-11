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
