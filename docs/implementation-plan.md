# TagWallet implementation plan

## Goal and agreed scope
Build an offline 509-card catalog, one Christmas batch for writing 50–100 cards, durable completion tracking, on-device content import, and complete backup/restore. Keep UIKit and the proven NFC cryptography/page-writing implementation. No cloud accounts/sync, multiple batches, printing, or new third-party dependencies. Artwork is for the app only.

## Architecture and persistence
- Shared WalletStore owns the effective catalog, keys, user overrides, images, batch and progress.
- Product identity is lowercase head + tail. Add optional cardNumber and imageAssetName; legacy JSON remains readable.
- Logical layers: bundled catalog; user library/overrides; progress. Catalog updates/imports cannot reset progress.
- Progress stores ordered batch IDs, per-card completedAt/source (nfc/manual)/switchTested, and current writing ID.
- Removing/readding membership preserves completion. Undo completion clears Switch-tested.
- Generation directories contain complete snapshots; validate and write before atomically switching active pointer. Retain previous generation for recovery. Never silently reset corrupt data.
- Migrate existing Documents/tagWallet.json, backing it up first. Preserve custom products, valid keys and distinct dumps, normalize dumps to 532 bytes, deduplicate by identity/bytes. Merge newly bundled products at each launch without duplicating existing data.
- If saving completion after successful NFC writing fails, explicitly report tag written/progress unsaved and retry persistence only.

## Catalog generator and images
- Python standard-library script with source/output paths and validation-only mode.
- Source: /Users/kashsethi/projects/Animal-Crossing-Amiibo.
- unfixed-info.bin -> dataKey; locked-secret.bin -> staticKey; validate 80 bytes and key layout.
- 509 dumps: Series 1–4 100 each, Series 5 48, Welcome Amiibo 50, Sanrio 6, Promos 5. Exclude installer bins.
- Source dumps 540 bytes; store first 532 as Base64. head bytes [84:88], tail [88:92]. Preserve number prefixes, derive names/series from filenames, reject duplicate IDs and invalid sources, deterministic output. Never log keys/dumps.
- Order Series 1–5, Welcome Amiibo, Sanrio, Promos; natural card order.
- Match AmiiboAPI repository artwork by exact head/tail; Nintendo fallback only with established series/card-number match. Manifest records revision, URLs, IDs, dimensions and coverage. Missing/ambiguous artwork uses placeholder.
- Bundle images; user image override > bundle > legacy remote URL > placeholder. Preserve aspect ratio; never upscale. Protect async image cell reuse.

## Import/export
Library & Backup provides Import BIN files, Import catalog, Import keys, Export backup, Restore backup. File picker copies to app-owned storage; no retained external file dependency. Suspend import/restore during NFC writes.
- BIN: multi-select 532/540-byte files; normalize; derive ID; skip identical dumps; append distinct dumps. Unknown entries default to Card/Imported and filename name, editable before/after import. Review additions/dumps/duplicates/rejections and explicitly confirm valid subset. Do not auto-complete or auto-add to batch; offer batch addition afterward.
- Images: card detail Choose image (Files PNG/JPEG), preview, validate <=10 MB and <=25 MP, normalize longest edge <=1600 without upscaling. Metadata edits preserve identity/dumps/progress.
- Catalog: legacy wallet JSON or schemaVersion 1 envelope with tagProducts, optional keys and optional Base64 images keyed by product ID. Generator supports embedded artwork. Review before commit; default preserve user overrides, optional Replace matching metadata/images switch. Optional key changes explicitly selected. Never remove absent products, import progress through catalog, or accept declared IDs mismatching dumps.
- Keys: explicitly labeled unfixed-info/locked-secret slots; validate before replacement; show presence only.
- Backup: schemaVersion 1 self-contained .tagwalletbackup JSON with effective wallet/keys/dumps, embedded images, progress, createdAt. Save via system Files/share flow outside own container; disclose keys included; show last successful export.
- Restore: validate entire backup, show counts/date, confirm replacement, keep pre-restore snapshot, atomically activate library+progress. Reject unsupported schemas without mutations. Input limit 500 MB checked before decode; recoverable disk-space errors.

## UI
- Catalog, Christmas batch and Library & Backup destinations. Default Card type with synchronized control. Search name/number, series filter, All/Remaining/Done.
- Grid artwork, number/name, badge precedence Done > Queued > Add. Tap card opens detail, Add changes membership. Multi-select add/remove; retain filters/scroll.
- Detail: Write card primary, batch membership, Mark/Undo done, Switch tested for completed only, edit metadata/image. Default first dump; secondary picker for multiple. Keep scanning and implement existing save-scanned-dump TODO via store.
- Batch: Remaining default, whole-batch done/total, saved insertion order, multi-add in catalog order, no duplicates, search/filter, Start/Resume, empty/completed states.
- Writer Ready -> Writing -> Success/Failure; capture ID/dump, one operation, prevent selection-changing navigation during write. Complete only on successful writer result, persist before next.
- Success shows card name/number, Write next and Close; next session requires tap. Skip rotates unfinished card to end, disabled for sole remaining. Fail/cancel/timeout/locked tag never completes. Confirm rewrites without incrementing count. Resume saved unfinished ID or first remaining.
- Main-thread UI/store changes, distinguish successful invalidation from cancellation, safely handle zero/multiple detections.

## Sequence and validation
1. Models/store/migration/atomic persistence.
2. Generator/full catalog/artwork.
3. Imports/editing/backup/restore.
4. Catalog/batch UI.
5. Sequential NFC integration.
6. Automated checks/build/UI inspection/device handoff.

Required tests: 509 counts/IDs/Base64/determinism; ten-card migration/custom preservation/idempotence; BIN normalization/duplicates/partial import; overrides/progress preservation; external file deletion after import; backup roundtrip and invalid/interrupted restore; batch add/remove/readd/undo/skip/resume/filter; fake writer captured-card success/failure/cancel; save retry never rewrites; cell reuse. Synthetic keys in tests.

Acceptance: offline 509 catalog; upgrade pilot without uninstall; phone-only imports; imports retain progress; 100-card batch survives restart/update; external backup restores after clean installation; accessible dark mode/larger text; tests and unsigned device build pass. Device-only: sequential writes, cancellation, locked-tag handling, imported-bin write, relaunch, Files export/restore. Switch verification stays manual.

## Collaboration and checkpoints
Use this document as scope authority and worklog.md as live handoff. Record completed work, checks, failures, decisions, next steps and checkpoint commits. Do not mark untested work complete. Commit coherent checkpoints with Conventional Commits. Preserve pre-existing local edits; never include personal Xcode userdata or .DS_Store. Do not spawn agents unless explicitly authorized by user or applicable instructions.
