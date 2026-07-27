[
  # Gettext compiles the PO `Plural-Forms` header into a literal
  # `%Expo.PluralForms{}` (an opaque struct) and hands it to
  # `Gettext.Plural.plural/2` from inside the generated `PhoenixKitComments.Gettext`
  # backend code. Dialyzer flags passing the opaque term outside `Expo`, but the
  # value is correct at runtime (the suite exercises it). Surfaced by the `ru`
  # catalog's custom `nplurals=3` plural AST.
  {"lib/phoenix_kit_comments/gettext.ex", :call_without_opaque},

  # `PhoenixKit.Settings.get_editor_mode/0` ships in a phoenix_kit release
  # newer than our `~> 1.7.189` floor, so it is legitimately missing from the
  # cores this module still supports. `CommentsComponent.default_editor_mode/0`
  # guards the call with `function_exported?/3` and falls back to `:hybrid`,
  # which is precisely the pattern dialyzer can't see through. Drop this entry
  # once the pin moves to a core that exports the function.
  {"lib/phoenix_kit_comments/web/comments_component.ex", :call_to_missing}
]
