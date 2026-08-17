# PR #31 — Quality sweep: stored XSS, authorization gaps, test harness

**Reviewed:** 2026-08-10 · **Author:** mdon · **Verdict:** merged into `main`,
no changes required. Released as **0.3.0** alongside the core `~> 2.0` pin.

+3419 / −1173 across 38 files. Reviewed as part of the phoenix_kit 2.0
ecosystem sweep. This is a **security release** — six other modules in the
umbrella depend on `phoenix_kit_comments`, and the XSS reached every reader of
a thread, so it got a closer read than the rest of the sweep.

## The stored XSS, verified independently

Comment bodies render with MDEx `unsafe: true`, which disables MDEx's own
escaping and makes whatever runs next the security boundary. That used to be
six regexes over the rendered string — a blocklist over HTML, which loses. The
PR replaces it with MDEx's `:sanitize` (ammonia), an allow-list, and removes
the `sanitize` attr entirely so there is no opt-out.

I did not take the PR's word for the fix. Running the five payloads through the
merged renderer (`MIX_ENV=test mix run`, calling `render_markdown/1` directly):

| Payload | Output | |
|---|---|---|
| `<script>alert(document.domain)` (no closing tag) | `""` | clean |
| `<a href=javascript:alert(1)>click</a>` (unquoted) | `<p><a rel="noopener noreferrer">click</a></p>` | clean |
| `<div style="position:fixed;…100vw;100vh">x</div>` | `<div>x</div>` | clean |
| `<img src=x onerror=alert(1)>` | `<img src="x">` | clean |
| `<svg onload=alert(1)>` | `""` | clean |

The first two are the ones the PR names as having survived the old regex pass,
and the mechanism it gives for each is right: the old pattern required a
matching `</script>`, and required the `href` value to be quoted. The `href` is
dropped rather than the whole anchor, and `rel="noopener noreferrer"` is added
for free — both are ammonia defaults.

The `div`/`style` removal is a real and non-obvious addition: MDEx's *default*
allow-list permits `style` on `div` while stripping it from `p`, which is
enough to lay a full-viewport overlay over the moderation UI's own buttons.
`rm_tag_attributes: %{"div" => ["style"]}` closes it. Confirmed
`MDEx.Document.default_sanitize_options/0` (`document.ex:1554`) and the
`rm_tag_attributes` option (`document.ex:1149`) both exist in the pinned MDEx.

**Severity is as claimed.** The admin moderation list renders the same
component, so an unprivileged commenter ran script in an owner's authenticated
session. Dropping the `sanitize` attr rather than defaulting it safely is the
right call — there is no caller for whom skipping sanitisation on a
user-authored comment body would be correct.

## API break, checked for blast radius

`render_markdown/2` becomes `render_markdown/1`. I grepped every sibling module
in the umbrella for callers of `PhoenixKitComments.Web.Markdown` — there are
none. `phoenix_kit_newsletters` and `phoenix_kit_posts` have functions of the
same *name*, but they are their own local implementations, not calls into this
module. So the break is contained; it is noted in the CHANGELOG regardless.

## Authorization and data-integrity findings

Accepted as described; each is a genuine defect and the fixes are the obvious
correct ones:

- **`save_decoration` had no check at all** — a logged-out visitor could rename
  any host record backed by a visible comment, and the `send_update` the host
  received was byte-identical to a legitimate one. The worst of the authz set,
  because it is silent.
- **Admin reads were unguarded while every write was checked.** Core's admin
  routes pipeline through `ensure_admin` only, and `permission: "comments"` on
  the tab governs sidebar visibility, not access — so an admin *without* the
  permission could read every comment on the platform, commenter emails, and
  the Giphy API key as a form value.
- **`@enabled` gated only the template**, so writes still landed on a disabled
  thread.
- **`save_edit` forwarded the decoration before checking permission** — a
  refused request still committed half an edit.
- **Reaction counters were inflatable.** Dedup was SELECT-then-INSERT with no
  unique index behind it (dropped during the uuid-FK migration, never
  recreated — which also makes the schemas' `unique_constraint` dead code).
  Reactions now serialise on the parent comment row. Note this is a *locking*
  fix, not a new index: no migration ships with the PR, which is consistent
  with the file list and is the right choice for a module whose tables come
  from core's chain.
- **The counter drifted permanently once duplicates existed** — `delete_all`
  removes N rows while the decrement was hardcoded to 1.
- **A repeat click committed a write and told nobody** — `after_reaction/3`
  skipped exactly the two atoms both paths produce.

## Verification

| Check | Result |
|---|---|
| `mix precommit` | **passes** against core 2.0.0 |
| `mix test` | **60 tests, 0 failures** (8 integration excluded — no Postgres available) |
| `mix test test/markdown_test.exs` | **14 tests, 0 failures** — the pinned payloads |
| Independent payload run | 5/5 neutralised, table above |

## Not verified here

The integration suite (8 tests, including `test/integration/reactions_test.exs`,
which is where the row-locking dedup fix is actually exercised) needs Postgres
and could not run in the review environment. The reaction-counter fixes are
reviewed by reading only. Worth running that file against a real database
before relying on the counter behaviour.
