# Import, backup, and recovery

For step-by-step phone instructions and choosing between BIN, catalog, and restore, see [Import guide](import-guide.md).

## Add cards without rebuilding
In **Library & Backup**, choose Import BIN files and select one or more files from Files/iCloud Drive. Review the counts and rejected files, then confirm. Both 532- and 540-byte dumps are accepted and normalized to 532 bytes. Identical dumps are skipped; additional dumps are retained. Names and images can be edited on a card's detail screen.

Import catalog accepts the original wallet JSON, or an envelope:

```json
{
  "schemaVersion": 1,
  "tagProducts": [],
  "images": {},
  "dataKey": null,
  "staticKey": null
}
```

Products retain the original fields plus optional `cardNumber` and `imageAssetName`. `images` maps lowercase head+tail IDs to Base64 PNG/JPEG bytes. Data fields in keys and dumps are Base64. Catalog import never imports progress or deletes absent products. Replacing existing metadata/images and using included keys are explicit, off-by-default choices.

Images selected from Files must be PNG/JPEG, at most 10 MB and 25 megapixels. They are saved offline, downscaled to a maximum 1600-pixel long edge without upscaling. Import files are limited to 500 MB.

## Build catalogs on your Mac

```bash
python3 scripts/import_catalog.py \
  --source /Users/kashsethi/projects/Animal-Crossing-Amiibo \
  --output private/catalog.json --validate-only

python3 scripts/import_catalog.py \
  --source /Users/kashsethi/projects/Animal-Crossing-Amiibo \
  --output private/catalog.json \
  --images TagWalletUI/CardImages
```

The second command creates a portable catalog with images suitable for Files import. Omit `--images` for the bundled catalog, whose images are separate resources.

Artwork is pinned to AmiiboAPI revision `6115745c56ff762ce212ced6fbad9ea195d659b3`. Refresh explicitly:

```bash
python3 scripts/fetch_artwork.py --revision 6115745c56ff762ce212ced6fbad9ea195d659b3
```

`TagWalletUI/CardImages/manifest.json` records URLs, dimensions, filenames, and errors. Current coverage: 509/509. Images remain Nintendo artwork; the manifest records their source rather than implying ownership.

## Backups
Export backup writes a self-contained `.tagwalletbackup` JSON with schemaVersion 1, createdAt (Foundation Codable Date), wallet, images, and progress. The backup includes keys: keep it private. Save outside the TagWallet app's own folder, such as iCloud Drive, before deleting the app. Rebuilding/installing an update with the same bundle identifier does not require deleting the app.

Restore backup is a separate replacement operation with a confirmation showing counts/date. Catalog imports cannot replace progress. A pre-restore snapshot is retained locally. External backups are required to recover after deleting the app.

Progress stores ordered active batch IDs, per-card completion time/source/Switch-tested flag, and resume ID. Optional `savedBatches` stores named lists with their IDs, ordered `cardIDs`, and `currentID`; `activeBatchID` selects the list projected into the existing batch/resume fields. Older snapshots without these fields migrate to one “My batch” list. Completion history is shared across lists. Successful NFC writing marks Done; Switch-tested is always manual.

## Storage and recovery
Documents contains UUID generation directories, each with a complete `snapshot.json`. `active-library` names the active generation; `previous-library` names the previous one. Library and progress are logically separate fields committed together. Atomic pointer replacement activates a fully staged snapshot. The active and previous generations are retained; old generations are pruned. Initial migration preserves `tagWallet-before-migration.json`; restore preserves `before-restore.tagwalletbackup`.

If active data is corrupt, the recovery screen offers the previous generation or an external backup. Invalid backups and imports leave active data untouched.
