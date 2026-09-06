CHANGELOG ENTRY TEMPLATE
========================

Copy the block below to the TOP of `0 Main/changelog.md` for each new build and
fill it in. Read "How this renders" first — the What's New screen
(`12 ChangelogView.swift`) is built around this exact structure, and skipping
parts of it (mainly the `## Area` headers) degrades the display.

Now that builds ship more often, keep entries SHORT: a few bullets per area is
plenty. Frequent small releases don't need a paragraph each — one clear
sentence per change is enough; save NOTES for anything actually important
(breaking change, migration, data-safety heads up), and skip it entirely most
releases.

----------------------------------
TEMPLATE — copy from here down
----------------------------------
----------------------------------
Version: YYYY.MM.DD Build: ##
NOTES
- (Optional. Omit this whole section on a normal build. Only use it for
  something release-critical the user must read before anything else —
  a breaking change, a delay, a required action.)

ADDED

## Area Name
- One short sentence per change. Start with what changed, not "Added".
- Keep it to a single clause where you can — the first ~5 words become the
  quick-glance summary, so front-load the important part.

## Another Area
- Another bullet.

FIXED

## Area Name
- What was broken and, briefly, the effect — not the internal cause.

CHANGED

## Area Name
- What's different now.

----------------------------------
TEMPLATE — end
----------------------------------

How this renders (What's New / Help > What's New):
- NOTES → a highlighted yellow callout at the very top of the version card.
- Every section's bullet count → small colored tally chips ("Added 6 · Fixed 2").
- The `## Area` headers from ADDED/FIXED/CHANGED → an indigo "AT A GLANCE" box,
  one line per bullet, auto-shortened to ~5 words. A bullet with no `##`
  header above it doesn't appear here — always use headers.
- The full, untrimmed bullet text → hidden behind a "Show full details"
  disclosure under the at-a-glance box, so it doesn't lengthen the page.

Rules that keep the auto-summary readable:
- Don't open a bullet with a parenthetical — it gets cut at the first "(".
- Avoid leading filler ("Added a new field to track...") — say the thing.
- A single `##` heading can repeat across ADDED/FIXED/CHANGED in the same
  version (e.g. "## Fuel Log" under both ADDED and FIXED) — the at-a-glance
  box merges them under one heading automatically.
