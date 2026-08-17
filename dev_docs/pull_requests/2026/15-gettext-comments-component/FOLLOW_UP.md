# Follow-up — PR #15

## Fixed (pre-existing)

- ~~`alt="GIF"` untranslated~~ — Wrapped.
- ~~Flash / error-label strings raw English~~ — All wrapped.
- ~~Edit button lacked an accessible label~~ — `aria-label` present.
- ~~Default title untranslated~~ — Wrapped.

## Fixed (quality sweep — 2026-08-09)

- ~~Inline JS error strings untranslated~~ — Replaced by reason codes mapped server-side; ru/et filled.

## Verification

`mix test` — 65 tests, 0 failures (integration excluded without core V166;
full suite green under `PHOENIX_KIT_PATH=../phoenix_kit`).
`mix precommit` — see the sweep summary; the pre-existing Oban dependency
warning and the `PhoenixKit.Mentions` undefined warnings against the published
core pin both predate this work.

## Open

None.
