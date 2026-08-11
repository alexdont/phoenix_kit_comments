defmodule PhoenixKitComments.ResourceHandler do
  @moduledoc """
  The contract a resource handler implements to hear about comments on its
  own resources.

  Register one per `resource_type`:

      config :phoenix_kit, :comment_resource_handlers, %{
        "post" => MyApp.Posts
      }

  Every callback is optional — implement only the events you care about — so
  a handler is free to be a two-line module that reacts to one thing.

  ## Why adopt the behaviour

  Dispatch is by `function_exported?/3`, and it always will be: a handler is
  named in host config, may live in another application, and may legitimately
  implement none of these. That is a good property, and it has one bad
  consequence — a callback this module never finds is indistinguishable from
  one you chose not to write. Misname `on_comment_create` (no `d`), take two
  arguments instead of three, and nothing happens: no error, no warning, no
  notification, and nothing to grep for.

  `@behaviour PhoenixKitComments.ResourceHandler` turns that into a compile
  warning at the point of the mistake. It is not required and changes nothing
  at runtime; it only makes the failure loud.

      defmodule MyApp.Posts do
        @behaviour PhoenixKitComments.ResourceHandler

        @impl true
        def on_comment_created(_type, post_uuid, comment) do
          MyApp.Posts.notify_author(post_uuid, comment)
        end
      end

  ## What is passed

  All callbacks receive the `resource_type` and `resource_uuid` the comment
  was filed against, so one handler can serve several types.

  Reaction callbacks take a map rather than the comment alone because the
  comment row carries its *author*, not the person reacting — `:liker_uuid`
  is the only place that appears.

  ## What is NOT decided here

  Reaction callbacks fire only when the state actually changed
  (`{:ok, :liked}`), never on an `:already_liked` no-op. Self-action skipping
  — not notifying someone who liked their own comment — is left to the
  handler, which is the only party that knows whether that matters.

  A callback that raises is caught and logged; it cannot fail the comment
  that triggered it.
  """

  alias PhoenixKitComments.Comment

  @typedoc "The resource type the comment was filed against, e.g. `\"post\"`."
  @type resource_type :: String.t()

  @typedoc "The uuid of the resource being commented on."
  @type resource_uuid :: Ecto.UUID.t()

  @typedoc """
  A reaction event. The comment plus who reacted — the row itself only knows
  its author.
  """
  @type reaction :: %{comment: Comment.t(), liker_uuid: Ecto.UUID.t()}

  @doc "A comment was created. Check `comment.parent_uuid` to tell a reply apart."
  @callback on_comment_created(resource_type(), resource_uuid(), Comment.t()) :: any()

  @doc "A comment was removed."
  @callback on_comment_deleted(resource_type(), resource_uuid(), Comment.t()) :: any()

  @doc "Someone liked a comment. Fires only on an actual change of state."
  @callback on_comment_liked(resource_type(), resource_uuid(), reaction()) :: any()

  @doc "Someone withdrew a like."
  @callback on_comment_unliked(resource_type(), resource_uuid(), reaction()) :: any()

  @doc "Someone disliked a comment."
  @callback on_comment_disliked(resource_type(), resource_uuid(), reaction()) :: any()

  @doc "Someone withdrew a dislike."
  @callback on_comment_undisliked(resource_type(), resource_uuid(), reaction()) :: any()

  @optional_callbacks on_comment_created: 3,
                      on_comment_deleted: 3,
                      on_comment_liked: 3,
                      on_comment_unliked: 3,
                      on_comment_disliked: 3,
                      on_comment_undisliked: 3

  @doc """
  The callbacks this package dispatches, as `{name, arity}`.

  Exposed so the dispatcher and the contract can be checked against each
  other — a callback added to one and not the other is exactly the silent
  mismatch this module exists to prevent.
  """
  @spec callbacks() :: [{atom(), arity()}]
  def callbacks, do: __MODULE__.behaviour_info(:callbacks) |> Enum.sort()
end
