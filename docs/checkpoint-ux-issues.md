# Device feedback at the current checkpoint

Recorded from user testing on 2026-11-10. Baseline: commit `fdd0cb9`, plus the local tuple-label warning fix in `TagProductsCollectionViewController.swift`. These are user-reported observations, not independently reproduced fixes. Device model, iOS version, and precise installed build are not yet recorded.

Status: open. Documentation only; do not treat the earlier passing unit tests/build as UX acceptance. Import instructions: [import guide](import-guide.md).

## UX-01 — General-purpose batch lists (product change)

The tab should be named **Batch**, without Christmas-specific wording. Users should be able to create a new batch list and add cards to that list. Update related detail actions and post-import prompts consistently.

The original plan deliberately supported one Christmas batch, so this is a scope change rather than only a label fix. Before implementing the data model, settle whether multiple saved lists coexist, how users select the destination list, and whether completion is shared between lists or belongs to each list. Preserve existing membership/progress during any migration. Naming, rename/delete behavior, and the initial empty state still need design.

Acceptance: users can create/select a batch list and add cards to it; existing saved work survives the change; no hardcoded Christmas wording remains in the user flow.

## UX-02 — Other cards' membership badges flash on Add/Remove

Reproduction: on the home/catalog grid, queue several cards, then tap Add or Remove on another card.

Observed: other queued cards briefly change from “Queued · Remove” to “+ Add”, then return. The screen appears to rerender broadly.

Expected: only the affected membership and relevant totals update; unrelated cards keep stable, correct badges and artwork. Preserve scroll position, selection, and filters.

Investigation lead only: the current store notification triggers grid refresh/reload. Cell reuse, notification timing, and rendering work need measurement; the cause is not established.

## UX-03 — Series filtering takes 2–3 seconds

Reproduction: select a series with approximately 100 matching cards in the 509-card catalog.

Observed: user reports a 2–3 second delay before results load.

Expected: filter changes respond promptly without blocking interaction. Measure filter computation, sorting, image loading/decoding, grid refresh, and main-thread work separately on the phone. Record cold/warm timings before and after any fix; do not assume the filter predicate is the bottleneck.

Acceptance: no repeatable multi-second pause for the reported series operation; results and counts remain correct while switching filters repeatedly.

## UX-04 — Dismissing filters can empty the grid

Reproduction: open Filters and swipe down to dismiss it.

Observed: list items disappear afterward.

Expected: dismissal without choosing an option preserves the current filter state and visible results. The filter interface also needs a usability redesign; the current interaction is reported as confusing and buggy.

Acceptance: repeat open/swipe-dismiss/cancel on both catalog and batch without losing results, selection, or scroll position; verify with search active and inactive.

## UX-05 — “All” does not restore all results

Reproduction: narrow the list with a filter, then choose “All” to return to all cards.

Observed: user cannot revert to showing all. The message says “All filter does work” but immediately says “can't revert back to showing all”; this issue records the latter behavior. Which All control was used remains to be confirmed.

Expected: distinguish All statuses, All series, and All types clearly. Provide an unambiguous way to clear filters and show the full catalog, accounting for any active search text.

Acceptance: each filter can be reset independently; clearing all filters/search restores the expected full catalog with no hidden restrictions.

## UX-06 — Runtime layout/animation warnings during browsing

User supplied a debug log while browsing. No timestamps or action-to-message mapping were supplied. Representative excerpts and diagnostic groups are preserved in [checkpoint-debug-log.md](checkpoint-debug-log.md).

Observed evidence: repeated unsatisfiable navigation-prompt constraints (zero-width prompt with 16-point margins), alert width conflicts (320 versus 366), transform-animation warnings, and coordinate conversion errors involving zero-height rectangles. Service/keyboard/handler warnings also occur.

Expected: investigate layout warnings alongside the filter presentation/dismissal repro. Capture a debugger stack at `UIViewAlertForUnsatisfiableConstraints` and correlate each warning with the action that triggers it. Do not suppress logs or attribute all framework messages to app defects without evidence.

Acceptance: the relevant catalog/filter flows work reliably; app-caused constraint conflicts are resolved. Remaining system diagnostics have a documented explanation or a separate reproducible issue.

## DOC-01 — Durable import instructions

User needs instructions that will still make sense six months later: what BIN and catalog import mean, which files to choose, review/confirmation behavior, duplicate handling, and how imports differ from backup restore. See [import-guide.md](import-guide.md) for the current implementation, and [file-formats.md](file-formats.md) for technical formats.

## Suggested next implementation order

1. Reproduce filter dismissal/reset failures and capture their layout diagnostics.
2. Profile filtering and Add/Remove badge updates; fix correctness and responsiveness.
3. Agree batch-list behavior and implement its migration/UI.
4. Re-run phone UX checks, import/backup checks, and the existing automated suite.

No application fixes for these reports have been made as part of this documentation checkpoint.
