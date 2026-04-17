# Metadata Rules

## Target Paths

- Target folder: `/Users/kyoheinogami/Library/Mobile Documents/iCloud~md~obsidian/Documents/OBSIDIAN DRIVE/10_CAPTURE/inbox-codex`
- Template: `/Users/kyoheinogami/Library/Mobile Documents/iCloud~md~obsidian/Documents/OBSIDIAN DRIVE/99_SYSTEM/Templates/Basic_Template.md`

## High-Confidence Defaults

- `status`: `inbox`
- `type`: `capture`
- `domain`: `仕事勉強` for Codex / Git / GitHub / VS Code / Obsidian / AI tooling topics
- `source`: first external URL in the note body; otherwise leave blank, including Codex/chat-derived notes with no external URL
- `origin`: infer from `source` when possible; Codex-oriented notes may still use `llm/codex` even when `source` is blank
- `tags`: only add obvious tags, up to 4
- `aliases`: leave blank unless there is a clear short alias already present in the note
- `context`: preserve existing wiki links; otherwise leave blank unless the body clearly names related notes with `[[...]]`
- `type_mbti`: leave blank unless a trusted value already exists
- `linter-yaml-title-alias`: leave blank unless a trusted value already exists

## ID Rules

- Use `REF-YYYYMMDD-HHMMSS` when `source` is non-empty.
- Use `NOTE-YYYYMMDD-HHMMSS` when `source` is blank.
- Keep an existing valid ID unless the user explicitly asks to regenerate IDs.

## Type Rules

- `capture`
  - default for inbox notes
  - direct Codex conversation summaries
  - rough working notes
  - unresolved study notes

- `resources`
  - stable reference-like notes tied to an article, video, paper, documentation page, or similar external source
  - only use when that classification is clearly stronger than `capture`

## Domain Rules

- `仕事勉強`
  - Codex, ChatGPT, Claude, Obsidian, Git, GitHub, VS Code, prompts, automation, programming, tooling, research workflow

- `情報管理`
  - vault structure, metadata schema, tagging strategy, frontmatter design, note-routing architecture
  - use only when the note is primarily about information architecture rather than general AI/tool learning

- `自分自身`
  - hobbies, entertainment, health, private life, personal reflection

## Origin Mapping

- `https://chatgpt.com/g/` -> `llm/gpt/project`
- `https://chatgpt.com/` -> `llm/gpt`
- Codex-oriented content with no external URL -> `llm/codex`
- `youtube.com` or `youtu.be` -> `youtube`
- `jamanetwork.com` -> `academic/jama`
- `pubmed.ncbi.nlm.nih.gov` or `ncbi.nlm.nih.gov` -> `academic/pubmed`
- `daigovideolab.jp` -> `dlabo/keigo`
- `github.com` -> `github`

Leave `origin` blank instead of guessing when no mapping is strong enough.

## Tag Heuristics

Use only high-confidence tags already common in the vault.

- Git / GitHub notes: `git/github`
- command-heavy Git notes: `git/command`
- Codex notes: `ai/agent/codex`
- VS Code notes: `vscode`
- Obsidian notes: `obsidian`
- academic paper summaries with no better fit: `topic`

Avoid generating long tag lists. `[]` is better than noisy tags.

## Examples

### Codex work note with no external URL

- `type: capture`
- `status: inbox`
- `domain: 仕事勉強`
- `source:` (blank)
- `origin: llm/codex`
- `id: NOTE-...`

### Paper summary with a journal URL in the body

- `type: resources` when clearly reference-like, otherwise `capture`
- `status: inbox`
- `domain: 仕事勉強`
- `source: <paper url>`
- `origin: academic/jama` or `academic/pubmed` when matched
- `aliases: 論文` only when that shorthand is clearly useful

## Non-Goals

- No automatic file moves
- No automatic filename rewrites
- No forced promotion from inbox to active/archived
- No `type_mbti` inference
- No `linter-yaml-title-alias` inference
