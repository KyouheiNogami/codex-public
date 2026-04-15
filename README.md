# codex-public

Public repository for shareable Codex assets and safe-to-publish defaults.

## Purpose

This repository is intended to hold files that are safe to publish, review, and reuse.
Use it for public skills, templates, examples, and other shareable artifacts.
Keep personal state, credentials, logs, and local-only files out of version control.

## Current Structure

- `.gitignore`
  Ignore rules for secrets, local state, generated files, editor metadata, and machine-specific noise.
- `skills-public/`
  Location for public Codex skills or examples.
  The included `.gitkeep` file keeps the directory in Git until real files are added.

## Adding Content

1. Put only public-safe files in `skills-public/` or another clearly shareable path.
2. Review changes for API keys, tokens, account data, machine-specific paths, and generated logs before committing.
3. Commit and push once the contents are safe to publish.

## Safety Notes

The current ignore rules already exclude common sensitive or local-only files such as:

- `.env` files and common certificate or key formats
- logs, caches, and temporary files
- editor settings and macOS metadata
- local Codex auth, history, session, prompt, and cache data

If a sensitive file was already committed once, adding it to `.gitignore` later does not remove it from Git history.
Remove tracked sensitive files before publishing.

## Repository Status

This repository is published at:

`https://github.com/KyouheiNogami/codex-public`
