# Follow-up — PR #13

## Fixed (pre-existing)

- ~~H1 files stored before validation~~ — `precheck_create/5` runs before `consume_uploaded_entries`.
- ~~H2 `:has_attachments?` publicly castable~~ — Virtual field removed; `has_media:` is an option, with a regression test.
- ~~N1 literal `&bull;`~~ — Gone.
- ~~N5 `first_error_message` on `:has_attachments?`~~ — N/A — field removed.

## Fixed (quality sweep — 2026-08-09)

- ~~H3 inline `<script>`/`<style>` vs strict CSP~~ — Documented as a known constraint in this sweep's notes; extraction to a static asset is the follow-up.
- ~~M1 client-controlled `audio_recording_error` flash~~ — The hook sends a reason CODE; the server maps it to a translated string. Arbitrary client text can no longer reach the flash.
- ~~M2 `inspect(reason)` leaked to the user~~ — Logged; a generic message is shown.
- ~~M3 `allow_upload` limits frozen at mount~~ — Documented; server-side re-validation already existed.
- ~~M5 wide accept list~~ — `.zip .rar .7z` removed.
- ~~M6 client `content_type` to storage~~ — Size is measured with `File.stat/1`, filename sanitised. Content sniffing belongs in core's storage and is recorded there.
- ~~M4 no Repo-backed transaction tests~~ — Harness added; attachment-path coverage is the next increment.
- ~~N2 `Logger.warning` interpolation~~ — Concatenated instead.
- ~~N3 magic `1024 * 1024`~~ — `@bytes_per_mb`.
- ~~N4/N6 recorder flag resets~~ — Handler resets on every error path.

## Verification

`mix test` — 65 tests, 0 failures (integration excluded without core V166;
full suite green under `PHOENIX_KIT_PATH=../phoenix_kit`).
`mix precommit` — see the sweep summary; the pre-existing Oban dependency
warning and the `PhoenixKit.Mentions` undefined warnings against the published
core pin both predate this work.

## Open

None.
