# Code Assistant Change Log

This document tracks changes made to your project by the Code Assistant (and related maintenance done alongside those changes).

Guidelines:
- Add entries under the Unreleased section while work is in progress.
- When changes ship (or you consider them finalized), move them into a dated release section below and summarize.
- Prefer concise, actionable bullets. Link to files/PRs where helpful.

Suggested sections per release:
- Added: New files, features, or capabilities introduced.
- Changed: Behavior changes, refactors, or updates to existing code.
- Fixed: Bug fixes and reliability improvements.
- Removed: Deletions or deprecations.
- Docs: Documentation and comments improvements.
- Internal: Build, tooling, CI, or housekeeping tasks.

## Unreleased

### Added
- 

### Changed
- 

### Fixed
- 

### Removed
- 

### Docs
- 

### Internal
- 

---

## 2025-10-25

### Added
- Created this change log at `0 documents/CHANGELOG.md` and linked it from `ROADMAP.md`.

### Docs
- Established conventions for tracking Assistant-driven changes (sections: Added/Changed/Fixed/Removed/Docs/Internal).

---

## How to use this file

### Automating with inline comments

You can add special inline comments in your Swift files and run the generator to update this change log automatically. After updating this file, the generator removes those comments from your code.

- Run: `./run-changelog-gen.sh` (optionally add `--dry-run` to preview)
- Default tag format (must start with CHANGELOG: and a section in brackets):
  - Line comment:
    ```swift
    // CHANGELOG: [Added] Implement Vehicle8 inactive filtering in pickers across Fuel/Trip views.
