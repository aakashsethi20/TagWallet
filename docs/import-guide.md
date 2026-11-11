# Importing cards into TagWallet

These instructions describe the implementation after the saved-list UX follow-up. Open **Lists** in Catalog or Batch to create/select a named list. Add and the post-import batch offer use that remembered active list; with one list, no repeated selection is needed. Membership/resume are per list; completion and Switch-tested history are shared.

## Choose the right option

| What you have / want | Option in Library & Backup |
| --- | --- |
| One or more raw card dump `.bin` files | Import BIN files |
| A TagWallet library/catalog `.json` containing card records and dumps, optionally images/keys | Import catalog |
| `unfixed-info.bin` (80-byte data key) | Import unfixed-info.bin (data key) |
| `locked-secret.bin` (80-byte static key) | Import locked-secret.bin (static key) |
| A full `.tagwalletbackup` to recover library, images, keys, batch and completion history | Restore backup |

BIN/catalog imports add or merge library content and preserve completion history. Restore backup replaces the library and progress after confirmation. Export a backup first if you want an external copy of your existing setup.

## Import BIN files on your phone

1. Put the card dump files in Files, for example in iCloud Drive or On My iPhone. Download/unzip an archive first; select the individual files, not a ZIP or folder.
2. Open TagWallet → **Library & Backup** → **Import BIN files**.
3. In the Files picker, select one or more card dump files. Supported lengths are **532 or 540 bytes**; 540-byte dumps are normalized to 532 bytes. Do not choose the 80-byte key files here.
4. Review “new cards”, “additional dumps”, “duplicate dumps”, and any rejected filenames. Confirm to import the valid subset, or Cancel to leave the library unchanged. If none are valid, nothing is imported.
5. The app then asks whether to add the imported cards to the active batch. Confirm to add them, or Cancel to keep the imported library content without adding batch membership. This second Cancel does not undo the import.
6. Find the cards in Catalog. Unknown cards use the filename as their initial name and “Imported” as their series. Open card detail → **Edit character details** or **Choose image** to customize them.

Identity comes from the dump bytes, not the filename. An identical dump already in the library is skipped; a different dump for the same identity is retained as another dump on that card. Import does not mark a card Done. Existing metadata is preserved for matching cards. Imported data is saved inside the app; it does not retain a dependency on the original file.

If an imported card is not visible, clear search and check status, series, and type filters. Filter/reset bugs are currently tracked in [checkpoint-ux-issues.md](checkpoint-ux-issues.md).

## Import a catalog on your phone

1. Put a compatible TagWallet catalog JSON in Files. This must contain `tagProducts` with valid card records/dumps; an arbitrary spreadsheet, image manifest, AmiiboAPI response, or backup is not a catalog import file.
2. Open **Library & Backup** → **Import catalog**, then select the JSON file.
3. On **Review catalog**, read the new-card/additional-dump/duplicate counts.
4. Leave **Replace matching metadata and images** off to preserve existing matching metadata and image overrides. Turn it on only when you intend incoming matching metadata/images to take precedence. Distinct dumps are merged either way; cards absent from the file are retained.
5. If the file includes keys, **Use included keys** appears. It defaults off. Enable it only if you intend to replace corresponding keys with those supplied by the catalog. Missing key slots do not clear existing keys.
6. Tap **Import**, or **Cancel** before committing. After import, accept or decline the separate offer to add these cards to the active batch.

Catalog imports do not import batch/completion history. Unsupported schemas, invalid identities/dumps, or invalid embedded images cause catalog validation to fail; catalog import does not offer the BIN flow's valid-subset import. Files are limited to 500 MB. Embedded PNG/JPEG images are individually limited to 10 MB and 25 megapixels and normalized to at most 1600 pixels on the longest edge without upscaling.

## Prepare a catalog on your Mac

The generator supports the folder layout in [miffycs/Animal-Crossing-Amiibo](https://github.com/miffycs/Animal-Crossing-Amiibo). From the TagWallet repository root, clone that source into the ignored `private/` directory, then generate your private catalog:


```bash
mkdir -p private
git clone https://github.com/miffycs/Animal-Crossing-Amiibo.git private/Animal-Crossing-Amiibo

python3 scripts/import_catalog.py \
  --source private/Animal-Crossing-Amiibo \
  --output private/tagwallet-catalog.json \
  --images TagWalletUI/CardImages
```

If you already have a checkout, skip the clone and pass its location to `--source`. The source must contain the expected series folders and `TagMo_Installer` key files.

Copy `private/tagwallet-catalog.json` to iCloud Drive, then select it using Import catalog on the phone. The generator expects the source folder structure described in [implementation-plan.md](implementation-plan.md); it is for this 509-card source collection, not an arbitrary folder of BINs. Use phone BIN import for individual dumps.

The generated JSON includes both keys from the source installer folder and embeds matching artwork when `--images` is supplied. Keep the file private. Omitting `--images` produces a catalog referencing bundled image resources instead of carrying portable artwork. Technical fields and validation-only commands are in [file-formats.md](file-formats.md).

## Keep a recoverable copy

Use **Export backup**, confirm, and save the `.tagwalletbackup` outside TagWallet's own folder, such as iCloud Drive. It includes keys, dumps, images, all saved batch lists, the active list, and progress. Use **Restore backup** to recover that full state, reviewing the date/counts before confirming replacement. A catalog is useful for sharing/merging library content; a backup is the file to keep for recovering your full setup.

## Source repository configuration

The tracked `initialTagWallet.example.json` is metadata-only: keys are null and dumps are empty. Supply your own data via Files imports. Do not commit generated catalogs; put Mac-generated private catalogs under ignored `private/`. URL import is not available; download to Files first.
