# Device acceptance checklist

Do not uninstall the pilot app to upgrade. Keep its bundle identifier and signing configuration.

- [ ] Install over pilot; all 509 cards appear, including the ten originals.
- [ ] Browse/search in airplane mode; artwork remains available.
- [ ] Select 50–100 cards, remove/re-add one, and confirm batch order and done count.
- [ ] Write two sequential cards. Each successful write moves to Done exactly once.
- [ ] Cancel an NFC session; the card stays Remaining.
- [ ] Present a locked tag; failure does not mark completion. Retry with a fresh blank tag.
- [ ] Skip a card; it stays unfinished and moves to the end.
- [ ] Relaunch; progress and resume position remain.
- [ ] Manually mark/undo Done; undo clears Switch-tested.
- [ ] Import new/duplicate/invalid BIN files together; review shows errors and duplicates.
- [ ] Import/edit an image, remove the external source, and confirm offline display.
- [ ] Import a catalog with metadata replacement off/on; completion remains unchanged.
- [ ] Import a scanned dump and confirm it is actually saved.
- [ ] Export backup to iCloud Drive; verify the file exists outside the app container.
- [ ] Restore that backup and verify images, keys, batch, and progress.
- [ ] Only after verifying an external backup, test a clean-install restore if desired.
- [ ] Test a written tag on Switch and mark Switch-tested manually.

Simulator tests cover persistence/import merging, recovery rejection, and fake NFC outcomes. They do not prove radio communication or Switch compatibility.
