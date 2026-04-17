---
name: obsidian-inbox-codex-metadata
description: Apply the YAML schema from /Users/kyoheinogami/Library/Mobile Documents/iCloud~md~obsidian/Documents/OBSIDIAN DRIVE/99_SYSTEM/Templates/Basic_Template.md to Markdown files in /Users/kyoheinogami/Library/Mobile Documents/iCloud~md~obsidian/Documents/OBSIDIAN DRIVE/10_CAPTURE/inbox-codex, filling suitable values for id, title, type, status, domain, tags, context, created, updated, source, and origin while intentionally leaving type_mbti and linter-yaml-title-alias blank unless the note already has trusted values. Use this skill when the user asks to batch-normalize, enrich, or review frontmatter for the inbox-codex folder in this Obsidian vault.
---

# Obsidian Inbox Codex Metadata

## Overview

This skill standardizes Markdown frontmatter for `10_CAPTURE/inbox-codex` with the key order from `99_SYSTEM/Templates/Basic_Template.md`.

Prefer conservative metadata over aggressive reclassification. The folder is an inbox, so the default posture is to preserve bodies, keep `status: inbox`, and avoid inventing weak aliases or context links.

## Scope

- Edit only Markdown files under `/Users/kyoheinogami/Library/Mobile Documents/iCloud~md~obsidian/Documents/OBSIDIAN DRIVE/10_CAPTURE/inbox-codex`.
- Use `/Users/kyoheinogami/Library/Mobile Documents/iCloud~md~obsidian/Documents/OBSIDIAN DRIVE/99_SYSTEM/Templates/Basic_Template.md` as the frontmatter schema and key order.
- Do not move files, rename files, or rewrite the note body unless the user explicitly asks.
- Ignore non-Markdown files and report them if they appear.

## Default Workflow

1. Confirm that the target folder exists and list the Markdown files inside it.
2. Read the template file and preserve its top-level key order.
3. Run the helper in dry-run mode first:

```bash
ruby scripts/apply_inbox_codex_template.rb --dry-run
```

4. If the results look reasonable, apply them:

```bash
ruby scripts/apply_inbox_codex_template.rb --write
```

5. Spot-check at least 2 files when files exist, and summarize:
- what was confirmed
- what stayed blank on purpose
- what still needs human review

## Decision Rules

- Preserve existing non-empty values when they are already plausible and do not conflict with the requested template-based normalization.
- Keep `type_mbti` blank by default. Only preserve an existing trusted value; do not infer a new one.
- Keep `linter-yaml-title-alias` blank by default. Only preserve an existing trusted value; do not infer a new one.
- Keep `source` blank when a note has no external URL, even if it is clearly derived from Codex or chat work.
- Prefer `type: capture` when confidence is low.
- Prefer `status: inbox` for files in this folder unless the note already has a trusted non-empty status.
- Prefer blank `aliases` and blank `context` over low-confidence guesses.
- Preserve extra frontmatter keys that already exist, but place template keys first in template order.

## When To Load More Detail

Read [references/metadata_rules.md](references/metadata_rules.md) when:

- a file could be either `capture` or `resources`
- `domain`, `origin`, or `tags` are ambiguous
- you need examples for `REF-` vs `NOTE-` IDs

## Notes About The Helper

The helper script:

- reads the template key order from the real `Basic_Template.md`
- works recursively under the target folder
- defaults to dry-run
- preserves note bodies
- preserves unknown existing frontmatter keys after the template keys

If the user asks for a one-off manual review instead of batch processing, you can skip the script and apply the same rules manually.
