# PR #30 Review — Open comment editors in the admin-configured default mode

- **Author:** Alexander Don (`alexdont`)
- **Reviewer:** Claude
- **PR:** https://github.com/BeamLabEU/phoenix_kit_comments/pull/30
- **Branch:** `alexdont:editor-default-mode` → `BeamLabEU:main`
- **State:** Merged 2026-07-27 as `1c59587` (review is post-hoc)
- **Diff size:** +5 / −0, 1 file (`lib/phoenix_kit_comments/web/comments_component.ex`)

## Summary

Three lines of intent, spread over three hunks:

1. `update/2` gains `assign(:editor_mode, PhoenixKit.Settings.get_editor_mode())`.
2. The **edit** form's `<.live_component module={Leaf}>` gains `mode={@ctx.editor_mode}`.
3. The **composer** form's `<.live_component module={Leaf}>` gains `mode={@ctx.editor_mode}`.

Goal: comment editors open in the site-wide default chosen under
Settings → Content Editor instead of always opening in Leaf's `:hybrid` default.

## Verdict

**Fix applied — the PR as merged crashes every comments component at runtime.**

The feature reads a core API that does not exist in any phoenix_kit version this
package can resolve. The intent is right and the wiring (`ctx` plumbing, both
editor sites) is correct; the call itself is not shippable as written. Rewritten
to degrade gracefully instead of raising, and to normalize whatever core
eventually returns into something Leaf can actually match on.

---

## BUG - CRITICAL: `PhoenixKit.Settings.get_editor_mode/0` does not exist -- FIXED

**File:** `lib/phoenix_kit_comments/web/comments_component.ex:219` (as merged)

The commit message claims the function is "new in phoenix_kit > 1.8.9". There is
no phoenix_kit 1.8.x. Verified against the actual dependency graph:

- `mix.exs` pins `pk_dep(:phoenix_kit, "~> 1.7.189")`.
- `mix.lock` resolves **1.7.213**.
- Hex's latest phoenix_kit release is **1.7.213** — the pin cannot reach anything
  newer, and no newer release exists to reach.
- `grep -rn "editor_mode" deps/phoenix_kit/lib/` → **zero hits**. `PhoenixKit.Settings`
  (`deps/phoenix_kit/lib/phoenix_kit/settings/settings.ex`) exports no
  `get_editor_mode/0`, and there is no "Content Editor" settings page anywhere in
  core to write such a setting.

`update/2` runs on **every** render and `send_update` of the component, so the
call is not on a rare path — it is on the only path. Every embed of
`PhoenixKitComments.Web.CommentsComponent` raises `UndefinedFunctionError` on
first render, whether or not rich text is enabled (the call sat outside the
`leaf_editor?` guard). The moderation dashboard and every host page embedding
comments go down with it.

This is not a "bump the pin" fix — there is nothing to bump to. The author was
almost certainly building against a local `PHOENIX_KIT_PATH=../phoenix_kit`
checkout that is ahead of Hex; the merged code assumed that checkout is what
everyone else has.

**Fix applied.** Capability-probe before calling, and fall back to Leaf's own
default when core is too old:

```elixir
@compile {:no_warn_undefined, {PhoenixKit.Settings, :get_editor_mode, 0}}

defp default_editor_mode do
  if Code.ensure_loaded?(PhoenixKit.Settings) and
       function_exported?(PhoenixKit.Settings, :get_editor_mode, 0) do
    __normalize_editor_mode__(PhoenixKit.Settings.get_editor_mode())
  else
    @default_editor_mode
  end
rescue
  _ -> @default_editor_mode
end
```

The `@compile` pragma mirrors the one already in this module for the optional
`Leaf` dep, and is what keeps `mix compile --force --warnings-as-errors` (the
first step of `mix precommit`) green while the function is still absent
upstream. Two alternatives were tried and rejected:

- `apply(PhoenixKit.Settings, :get_editor_mode, [])` — avoids the pragma, but
  `mix credo --strict` rejects it (`Credo.Check.Refactor.Apply`: "Avoid `apply/2`
  and `apply/3` when the number of arguments is known").
- Binding the module to a variable first (`settings = PhoenixKit.Settings;
  settings.get_editor_mode()`) — Elixir 1.19 still resolves the alias and emits
  the same undefined-function warning, so this buys nothing.

Dialyzer sees through neither trick — it reports `call_to_missing` for a call
guarded by `function_exported?/3`, which is exactly the shape it can't reason
about. Recorded as a documented `.dialyzer_ignore.exs` entry (the same mechanism
the repo already uses for the Gettext opaque-struct case), with a note to delete
it once the pin moves to a core that exports the function.

The `rescue` matches the module's existing stance for settings reads that can
fail when the DB isn't available (see `PhoenixKitComments.enabled?/0`). When core
does ship `get_editor_mode/0`, this code starts honouring it with no further
change — and consumers still on 1.7.x keep working.

## BUG - HIGH: a string setting value would crash inside Leaf -- FIXED

**File:** `lib/phoenix_kit_comments/web/comments_component.ex:1167,1605` (as merged)

Even granting a future core that exports `get_editor_mode/0`, the value was piped
straight into Leaf without a type contract. Leaf declares:

```elixir
# deps/leaf/lib/leaf.ex:91
attr(:mode, :atom, default: :hybrid, values: [:visual, :hybrid, :markdown, :html])
```

and its normalizer has **no catch-all clause**:

```elixir
# deps/leaf/lib/leaf.ex:2624
defp normalize_mode(mode, deny)
     when mode in [:visual, :hybrid, :markdown, :html] and is_list(deny) do
```

PhoenixKit settings round-trip through the DB as **strings** (`get_setting/2`,
`get_setting_cached/2` and friends all return binaries). If `get_editor_mode/0`
returns `"visual"` rather than `:visual` — or returns a value from a future
settings page that Leaf's version doesn't know, e.g. `"wysiwyg"` — Leaf's
`update/2` dies with `FunctionClauseError` and takes the editor down with it.
This module has no control over what core returns, so the coercion belongs on
this side of the boundary.

**Fix applied.** A `__normalize_editor_mode__/1` funnel accepting the four atoms,
their string forms, and falling back to `:hybrid` (Leaf's own default) for
everything else. The mode list is pinned in `@leaf_editor_modes` with a comment
tying it to Leaf's `attr` declaration, and covered by tests so the two lists
can't silently drift apart.

## IMPROVEMENT - MEDIUM: a settings read on every re-render, for a value Leaf reads once -- FIXED

**File:** `lib/phoenix_kit_comments/web/comments_component.ex:219` (as merged)

`assign/3` re-evaluates on every `update/2` — i.e. on every parent re-render and
every partial `send_update`. That's a settings lookup per render for a site-wide
constant, and it buys nothing, because Leaf only ever honours `:mode` on its
**first** render:

```elixir
# deps/leaf/lib/leaf.ex:247
{parent_mode, assigns} = Map.pop(assigns, :mode, :hybrid)
...
|> assign_new(:mode, fn -> parent_mode end)
```

After the editor mounts, later `:mode` values from the parent are discarded (by
design — so a user's in-editor mode switch survives parent re-renders). So the
repeated read is pure cost.

This also cuts against the grain of the code immediately below it, which goes out
of its way to avoid exactly this:

> `# Re-run it when comments reload or when those inputs change, rather than firing two queries on every parent re-render / send_update.`

**Fix applied.** `assign_new(:editor_mode, &default_editor_mode/0)` — one read per
component lifetime, identical on-screen behaviour.

## OBSERVATION: mode changes don't reach an already-open editor

Because of the Leaf `assign_new` above, an admin flipping the site default while a
comment editor is open on someone's screen won't change that editor's mode until
it remounts. This is Leaf's intended behaviour (it protects the user's own mode
toggle), and forcing it would require a `send_update(Leaf, action: :set_mode, …)`
broadcast that would stomp on whatever mode the user had picked. **Left as-is on
purpose** — the cure is worse than the symptom.

## BUG - MEDIUM: stale `mix.lock` entry breaks `mix precommit` (not from this PR) -- FIXED

Not attributable to PR #30 — it arrived with the `lib upgrades` commit `2465979`
that followed the merge — but it blocked validating this review, so it is fixed
here rather than left for the next person:

```
$ mix deps.unlock --check-unused
** (Mix) Unused dependencies in mix.lock file:
  * :beamlab_ex_aws_sqs
```

`deps.unlock --check-unused` is step 2 of `mix precommit`, so the gate could not
run to completion on `main`. Core declares the package as
`{:ex_aws_sqs, "~> 5.0", [hex: :beamlab_ex_aws_sqs, …]}`, and the lock had picked
up a second, orphaned entry under the Hex name. Cleared with
`mix deps.unlock --unused` (one line removed from `mix.lock`; nothing in the
resolved dependency set changes).

## OBSERVATION: `@ctx` plumbing is correct

Worth recording since it's the non-obvious part of the diff and it is *right*.
`@ctx` is not a purpose-built struct — the template passes the component's whole
assigns map through (`ctx={assigns}` at `comments_component.html.heex:176`, `:197`,
`:210`), and `render_comment/1` forwards it verbatim down the recursive tree
(`ctx={@ctx}` at `:1334`, `:1361`, `:1931`). So a plain `assign(:editor_mode, …)`
in `update/2` genuinely does reach both `@ctx.editor_mode` read sites, including
the deeply nested reply editors. No missing plumbing.

## What Was Done Well

- **Both editor sites covered.** The composer and the edit form were changed
  together — a partial application would have been a confusing split-brain where
  new comments honour the setting and edits don't.
- **The `ctx` indirection was understood.** Assigning in `update/2` and reading
  `@ctx.editor_mode` is the correct move for this component's rendering model;
  it would have been easy to thread a new attr through three call sites instead.
- **Comment left at the assign.** The one-line rationale ("Site-wide default
  editor mode … passed to every Leaf instance this component renders") matches
  the module's high comment density and explains the *why*, not the *what*.

## Tests added

`test/phoenix_kit_comments_test.exs` — `describe "editor mode normalization"`:

- every mode Leaf accepts passes through unchanged,
- each mode's string form (the shape settings actually round-trip as) maps to the
  right atom,
- `nil`, `""`, unknown strings/atoms, integers and maps all fall back to `:hybrid`.

The atom list is asserted explicitly rather than read from the module attribute,
so if Leaf's accepted modes change, the test fails instead of tracking the drift.

## Validation

`mix hex.audit` (step 3 of `mix precommit`) is skipped — it fails on transitive
hackney CVEs inherited from core, which is a known, pre-existing condition and not
a release blocker. Every other gate step was run:

| Step | Result |
|---|---|
| `mix format` | clean |
| `mix compile --force --warnings-as-errors` | green |
| `mix deps.unlock --check-unused` | green (after clearing the stale lock entry) |
| `mix credo --strict` | 358 mods/funs, **no issues** |
| `mix dialyzer` | **passed successfully** (3 skipped, 0 unnecessary skips) |
| `mix test` | **46 tests, 0 failures** |

## Files changed by this review

- `lib/phoenix_kit_comments/web/comments_component.ex` — capability-probed,
  normalized, once-per-lifetime editor-mode resolution.
- `test/phoenix_kit_comments_test.exs` — mode normalization coverage.
- `.dialyzer_ignore.exs` — documented `call_to_missing` skip for the guarded call.
- `mix.lock` — orphaned `:beamlab_ex_aws_sqs` entry removed.
