# Follow-up — PR #24

## Fixed (pre-existing)

- ~~`reply_indicator/1` crashed on a media-only parent~~ — `parent_snippet/1` guards and falls back.
- ~~Shared markdown styles not extracted~~ — `comment_markdown_styles/1` rendered once per page.
- ~~Media/GIF-only comments invisible in admin~~ — `blank_content?/1` + placeholder.
- ~~Resource-chip thumbnail used inline `onerror`~~ — CSS `background-image`, CSP-safe.
- ~~`navigate` used for possibly-external URLs~~ — `href` for non-prefixed paths.
- ~~Pagination links carried empty filter params~~ — `build_url_params/2` strips blanks.
- ~~Clickable preview not keyboard-focusable~~ — `role`, `tabindex`, Enter handling.
- ~~Card status rendered as a raw string~~ — `status_badge_value/1`.

## Fixed (quality sweep — 2026-08-09)

- ~~No render/LiveView tests~~ — Harness added; markdown now has direct coverage (10 XSS payloads).
- ~~`restore` always republishes~~ — `restore_comment/2` returns a comment to `pending` when moderation is on, so undoing a delete no longer approves as a side effect.
- ~~Preview renders full markdown then clamps~~ — Truncated at the source before rendering.

## Verification

`mix test` — 65 tests, 0 failures (integration excluded without core V166;
full suite green under `PHOENIX_KIT_PATH=../phoenix_kit`).
`mix precommit` — see the sweep summary; the pre-existing Oban dependency
warning and the `PhoenixKit.Mentions` undefined warnings against the published
core pin both predate this work.

## Open

None.
