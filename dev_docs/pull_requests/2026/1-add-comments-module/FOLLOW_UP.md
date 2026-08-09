# Follow-up — PR #1

## Fixed (pre-existing)

- ~~SQL wildcard injection via ILIKE search~~ — `escape_like_pattern/1` escapes `\`, `%` and `_`, applied at the search call site.
- ~~`delete_comment/1` hard-deleted rows~~ — Soft delete via status.
- ~~`phx-value-uuid` vs handler reading `"id"`~~ — Handlers match `%{"uuid" => uuid}`.
- ~~No authz on admin moderation actions~~ — `check_authorization/1` on every write.
- ~~`comments_moderation` never applied~~ — `maybe_set_initial_status/1`.
- ~~`max_depth` / `max_length` unenforced~~ — `validate_depth/1` + `validate_content_length/1` via `run_cheap_validators/2`.
- ~~O(n^2) comment-tree build~~ — `Enum.group_by`.
- ~~Like/dislike not mutually exclusive~~ — Each path removes the opposing reaction.
- ~~IDOR on comment delete~~ — Resource ownership checked in `do_delete_comment/2`.
- ~~Like/dislike double-click race~~ — Precheck inside the transaction (hardened further in this sweep — see below).

## Fixed (quality sweep — 2026-08-09)

- ~~Like/dislike double-click race (deepened)~~ — The precheck had no DB backstop — the composite unique index was dropped during the uuid-FK migration and never recreated, so the schemas' `unique_constraint` is dead code. Reactions now serialise on the parent comment row, and the counter decrements by rows actually deleted rather than by one.
- ~~Test coverage gaps (CRUD, authz, depth)~~ — `test/support` + `DataCase` added; the module had no repo configured at all, which is why ~40 public functions were untestable and some tests were asserting the rescue path.
- ~~Integration tests for admin actions~~ — Same — harness now exists; reaction coverage landed with it.
- ~~Depth semantics undocumented~~ — AGENTS.md now states depths are 0-based and `>= max` rejects, so 10 yields 0–9.

## Verification

`mix test` — 65 tests, 0 failures (integration excluded without core V166;
full suite green under `PHOENIX_KIT_PATH=../phoenix_kit`).
`mix precommit` — see the sweep summary; the pre-existing Oban dependency
warning and the `PhoenixKit.Mentions` undefined warnings against the published
core pin both predate this work.

## Open

None.
