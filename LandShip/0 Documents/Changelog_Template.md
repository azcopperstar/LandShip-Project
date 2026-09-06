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
- Short lead-in phrase: rest of the detail, in a normal sentence.
- Another change: more detail if it needs it.

## Another Area
- Another bullet: detail.

FIXED

## Area Name
- What was broken: the effect, briefly — not the internal cause.

CHANGED

## Area Name
- What's different now: any detail worth adding.

----------------------------------
TEMPLATE — end
----------------------------------

How this renders (What's New / Help > What's New):
- NOTES → a highlighted yellow callout at the very top of the version card.
- Every section's bullet count → small colored tally chips ("Added 6 · Fixed 2").
- The `## Area` headers from ADDED/FIXED/CHANGED → an indigo "AT A GLANCE" box,
  one line per bullet. A bullet with no `##` header above it doesn't appear
  here — always use headers.
- The full, untrimmed bullet text → hidden behind a "Show full details"
  disclosure under the at-a-glance box, so it doesn't lengthen the page.

How the quick-glance summary is picked (as of build 92+):
- Write every bullet as "Lead-in phrase: rest of the detail." — everything
  BEFORE the first ":" is used as-is as the at-a-glance line; everything
  including and after the ":" only shows up behind "Show full details".
- Keep the lead-in short (a few words) and make it stand on its own — it's
  the only part most people will read.
- If a bullet is already short enough that it doesn't need elaboration, a
  colon is optional; the whole bullet is used both places.
- Bullets written without a colon (mainly pre-build-92 entries) fall back to
  an automatic ~5-word truncation — fine for old entries, but every new bullet
  going forward should use the colon form intentionally instead of relying on
  that fallback.
- A single `##` heading can repeat across ADDED/FIXED/CHANGED in the same
  version (e.g. "## Fuel Log" under both ADDED and FIXED) — the at-a-glance
  box merges them under one heading automatically.
