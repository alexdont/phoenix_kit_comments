# Follow-up — PR #28

## Fixed (pre-existing)

- ~~Hard dep on `PhoenixKit.ResourceLinks` vs the declared floor~~ — Floor covers it.

## Fixed (quality sweep — 2026-08-09)

- ~~Gettext sentence fragmentation~~ — Collapsed to one msgid per sentence with the code tokens as placeholders; ru and et re-translated.
- ~~`validate_resource_path/2` flashes untranslated~~ — All five wrapped; ru/et filled.
- ~~`comments_rich_text` missing from AGENTS.md~~ — Added to the settings table.

## Verification

`mix test` — 65 tests, 0 failures (integration excluded without core V166;
full suite green under `PHOENIX_KIT_PATH=../phoenix_kit`).
`mix precommit` — see the sweep summary; the pre-existing Oban dependency
warning and the `PhoenixKit.Mentions` undefined warnings against the published
core pin both predate this work.

## Open

None.
