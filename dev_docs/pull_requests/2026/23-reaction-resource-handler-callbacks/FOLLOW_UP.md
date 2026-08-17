# Follow-up — PR #23

## Fixed (pre-existing)

- ~~Extra full-row SELECT per reaction~~ — `after_reaction/3` shares one lookup.
- ~~Review file committed at repo root~~ — Moved under `dev_docs/pull_requests/`.
- ~~CHANGELOG missing the lookup optimisation~~ — Recorded under 0.2.9.

## Fixed (quality sweep — 2026-08-09)

- ~~No test coverage for reaction dispatch~~ — `test/integration/reactions_test.exs` covers counters, duplicates, repeat clicks, per-user isolation and the broadcast.
- ~~Callbacks undeclared (no `@callback`)~~ — `PhoenixKitComments.ResourceHandler` declares all seven with `@optional_callbacks`.

## Verification

`mix test` — 65 tests, 0 failures (integration excluded without core V166;
full suite green under `PHOENIX_KIT_PATH=../phoenix_kit`).
`mix precommit` — see the sweep summary; the pre-existing Oban dependency
warning and the `PhoenixKit.Mentions` undefined warnings against the published
core pin both predate this work.

## Open

None.
