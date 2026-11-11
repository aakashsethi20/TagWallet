# TagWallet

An iOS app for managing NTAG215 cards, an offline catalog, named batch lists, and sequential NFC writing. Based on [Kevin Brewster’s TagWallet](https://github.com/kevinbrewster/TagWallet); original MIT license and copyright are retained in [LICENSE](LICENSE).

## Build and run

Open `TagWallet.xcodeproj` in Xcode, select your signing team and a unique bundle identifier, then run the TagWallet scheme on your iPhone. The project minimum is iOS 17. Real NFC requires a supported iPhone; the simulator supports catalog/UI testing only.

The bundled `TagWalletUI/initialTagWallet.example.json` contains 509 card metadata records and **no keys or card dumps**. Offline artwork is included. A fresh installation can browse the catalog immediately; writing requires importing your own valid dumps and both keys. Cards with no dump cannot be written.

## Supply your own data

Open **Library & Backup**:

- **Import BIN files** adds one or more 532/540-byte card dumps.
- **Import catalog** merges a compatible TagWallet JSON containing card records and dumps, optionally images/keys.
- **Import unfixed-info.bin (data key)** and **Import locked-secret.bin (static key)** configure the two 80-byte key slots.
- **Export backup / Restore backup** saves or restores the full private library, named lists, images, keys, and completion history.

See the [step-by-step import guide](docs/import-guide.md) and [file formats](docs/file-formats.md). URL imports are not implemented: download files into Files first, then import them. No download of keys/dumps occurs automatically.

To prepare a private catalog on a Mac, use `scripts/import_catalog.py` with your own source files and write the output under the ignored `private/` directory. Never overwrite the tracked example with personal data. The ignored legacy `initialTagWallet.json` is not bundled by this project; import it through Files instead. Ignore rules do not protect arbitrary renamed JSON files: review staged changes before committing.

Existing installed libraries remain in app storage when updating with the same bundle identifier. Export a backup before uninstalling or changing bundle identifiers.

## Batch lists

Use **Lists → New batch** in Catalog or Batch. Add uses the remembered active list directly, including a one-list setup. Membership/resume is per list; completion and Switch-tested history is shared.

## Validation and status

Run Cmd-U using the TagWallet scheme, or run:

```bash
xcodebuild -project TagWallet.xcodeproj -scheme TagWallet \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
python3 -m unittest discover -s scripts -p 'test_*.py'
```

Tests use synthetic dump/key fixtures. [UX issues and implementation status](docs/checkpoint-ux-issues.md) tracks completed changes and pending device verification. NFC, Files-provider, and Switch checks remain in the [device checklist](docs/device-checklist.md).

[Publication checkpoint](docs/repository-publication-checkpoint.md) records sanitization and migration status. [Worklog](docs/worklog.md) and [implementation plan](docs/implementation-plan.md) contain historical development context; statements about an earlier bundled writable catalog describe the private development checkpoint, not this public-source configuration.
