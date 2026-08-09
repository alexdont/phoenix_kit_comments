defmodule PhoenixKitComments.ResourceHandler do
  @moduledoc """
  The contract a host module implements to hook into comments.

  Every callback is optional and every one is invoked through
  `function_exported?/3`, so a module may implement one, some or none —
  `@behaviour` here buys compile-time checking of the ones you DO write,
  which duck-typing never did. Before this existed the six-callback contract
  lived only in a moduledoc, so a typo in a callback name (or drift in its
  arity) produced silence: the callback simply never fired and nothing said
  why.

  Adopting it is opt-in and non-breaking — handlers registered today keep
  working untouched.

      defmodule MyApp.Orders do
        @behaviour PhoenixKitComments.ResourceHandler

        @impl true
        def resolve_comment_resources(uuids), do: ...

        @impl true
        def on_comment_created(_type, _uuid, comment), do: ...
      end

  ## Paths are RAW

  `resolve_comment_resources/1` returns `path` WITHOUT the PhoenixKit url
  prefix — the renderer applies `Routes.path/1` once. A handler that
  pre-prefixes gets a doubled prefix.
  """

  @typedoc "The host's own type key for a commentable record, e.g. `\"order\"`."
  @type resource_type :: String.t()

  @typedoc "The record's uuid."
  @type resource_uuid :: String.t()

  @doc """
  Titles and RAW deep-links for the given uuids.

  Returns `%{uuid => %{title: String.t(), path: String.t()}}`. May also
  carry `:full_title` (tooltip) and `:thumb_url` (chip thumbnail); a uuid
  the handler does not recognise is simply absent from the map.
  """
  @callback resolve_comment_resources([resource_uuid()]) :: %{
              optional(resource_uuid()) => map()
            }

  @doc "A comment was created on one of this handler's records."
  @callback on_comment_created(resource_type(), resource_uuid(), struct()) :: any()

  @doc "A comment was soft-deleted."
  @callback on_comment_deleted(resource_type(), resource_uuid(), struct()) :: any()

  @doc "Someone liked a comment. `payload` carries `:comment` and `:liker_uuid`."
  @callback on_comment_liked(resource_type(), resource_uuid(), map()) :: any()

  @doc "Someone removed their like."
  @callback on_comment_unliked(resource_type(), resource_uuid(), map()) :: any()

  @doc "Someone disliked a comment."
  @callback on_comment_disliked(resource_type(), resource_uuid(), map()) :: any()

  @doc "Someone removed their dislike."
  @callback on_comment_undisliked(resource_type(), resource_uuid(), map()) :: any()

  @optional_callbacks resolve_comment_resources: 1,
                      on_comment_created: 3,
                      on_comment_deleted: 3,
                      on_comment_liked: 3,
                      on_comment_unliked: 3,
                      on_comment_disliked: 3,
                      on_comment_undisliked: 3
end
