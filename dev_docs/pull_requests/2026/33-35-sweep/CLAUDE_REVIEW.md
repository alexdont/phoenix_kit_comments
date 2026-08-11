# PRs #33, #34, #35 — sweep review

**Reviewer:** Claude (post-merge sweep, 2026-08-11)
**Verdict:** All three merged. One MEDIUM fix, and #35 resolved against an
existing implementation rather than taken as written.

---

## PR #35 — Give resource handlers a behaviour to implement

**This PR was a second implementation of something main already had**, which is
why it showed as `CONFLICTING`. Commit `6e129d1` ("Declare the resource-handler
contract, and correct the docs") had already added
`lib/phoenix_kit_comments/resource_handler.ex`. The conflict was `add/add`, not
a textual overlap — two independent answers to the same gap.

The two differ in a way that matters:

| | main (`6e129d1`) | PR #35 |
|---|---|---|
| callbacks | **7** | 6 |
| `resolve_comment_resources/1` | declared | **absent** |
| callback payload types | `struct()` / `map()` | `Comment.t()` / `reaction()` |
| `callbacks/0` introspection | no | yes |
| drift test vs dispatcher | no | yes |

Taking the PR's file wholesale would have **silently dropped
`resolve_comment_resources/1` from the contract**. That is the batch
title/deep-link lookup the renderer depends on, and the one the "Paths are RAW"
rule is documented against. Hosts implementing it with `@impl true` would start
getting *"module attribute @impl was not set... behaviour does not specify such
callback"* — the exact class of silent-contract-drift failure this module exists
to prevent, caused by the module meant to prevent it.

The PR's own test would have caught it, in the sense that it asserts *"every
callback takes three arguments"* — which is true of the six events and false of
`resolve_comment_resources/1`. That assertion only passes because the file it
tests dropped the seventh callback.

**Resolution:** kept main's superset and grafted what the PR genuinely adds —
`callbacks/0`, the tighter `Comment.t()` / `reaction()` typing, and the "why
adopt the behaviour" rationale, which is the best-argued part of the PR and was
missing from main's version.

Added `event_callbacks/0` so the arity check and the drift check can say "the
events" instead of assuming the contract is uniform, plus a test pinning that
`{:resolve_comment_resources, 1}` stays in `callbacks/0` — a direct regression
test for the resolution itself.

The drift test (regex-scanning the dispatcher source for `:on_comment_*` atoms)
is a heuristic, but a sound one here: the moduledoc names the callbacks without
leading colons, so only real dispatch sites match. Verified the six it finds are
the six declared.

---

## PR #34 — Let hosts read and retarget comments by metadata

Good motivation and a correct diagnosis: hosts keying comments on a non-UUID
tuple were dropping to schemaless SQL against this package's table, and
inheriting its sharp edges (uuid columns load as 16-byte binaries there, so
string comparison fails silently). Giving them `:metadata` and `:any` is the
right answer.

`update_metadata/2` and `merge_metadata/3` are atomic `COALESCE(?, '{}'::jsonb)
|| ?` writes — correct, and the `COALESCE` is load-bearing since the column is
nullable and `NULL || jsonb` is `NULL`. Refusing an empty `match` in
`merge_metadata/3` is the right call for a statement that can rewrite a whole
resource type.

### BUG - MEDIUM: `count_replies/2` reported zeros silently

```elixir
rescue
  _ -> Map.new(Enum.uniq(parent_uuids), &{&1, 0})
```

A failed query became `0` for every parent, with nothing logged. Unlike a
degraded read that looks degraded, "0 replies" is a **plausible** answer — a
thread list renders normally and simply understates itself, and nothing
anywhere distinguishes it from a genuinely quiet thread.

**Fixed on main:** logs at `:warning` with the failure reason and the number of
parents affected before degrading. The zeros stay — a thread list that renders
is better than one that crashes — but they are now traceable.

The same shape exists in the pre-existing `count_comments/3` (`rescue _ -> 0`).
Left alone: it is out of this PR's scope and the sweep did not want to churn an
untouched function, but it is worth the same treatment next time that file is
open.

### Notes, not defects

- `apply_metadata_filter/2` compares with `->>` (text-to-text). `jsonb ->> $1`
  resolves to the `text` overload because `text` is the preferred type in the
  string category, so the bound-parameter form is safe; the alternative (`@>`
  containment) would make `"1"` and `1` different questions, which is not what a
  caller filtering on a slug wants.
- `merge_metadata/3` also rewrites soft-deleted comments. Correct for the rename
  case it exists for.
- Test coverage for the metadata paths is the empty-match guard only; the query
  paths need a database, which this environment has not got.

---

## PR #33 — Translate sidebar tab labels, fix copy-pasted ru/et entries

Straightforward and correct. Two things worth recording, because both are
invisible to the usual checks:

- **`fuzzy` entries are not used at runtime.** Gettext ignores a fuzzy `msgstr`
  and falls back to the msgid, so the affected labels were rendering in English
  despite having a translation sitting right there. Clearing the flags is what
  actually turned those translations on.
- **Two plural forms had dropped their `%{action}` interpolation**, so a bulk
  action reported "5 kommentaari" ("5 comments") instead of "5 comments
  deleted" — the result, minus the thing that happened.

The tab change (`gettext_backend` + `gettext_domain` on both tabs) is required
for the labels to resolve at all; without it the label is passed through
untranslated regardless of what the .po files say.
