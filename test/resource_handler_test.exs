defmodule PhoenixKitComments.ResourceHandlerTest do
  @moduledoc """
  The resource-handler contract.

  Dispatch is by `function_exported?/3` and always will be — a handler is
  named in host config, may live in another application, and may legitimately
  implement none of these. The cost of that is a callback this package never
  finds being indistinguishable from one the host chose not to write: misname
  it, or take the wrong number of arguments, and nothing happens anywhere.

  The behaviour exists to turn that into a compile warning. Which makes the
  behaviour itself the thing that can now drift: a callback added to the
  dispatcher and not the contract is the same silent failure wearing a
  different hat, so that pairing is what these check.
  """
  use ExUnit.Case, async: true

  alias PhoenixKitComments.ResourceHandler

  @source "lib/phoenix_kit_comments.ex"

  describe "the contract" do
    test "declares every callback optional" do
      # A handler that cares about one event should be a two-line module. If
      # any of these were required, adopting the behaviour would mean writing
      # five stubs, and nobody would adopt it.
      optional = ResourceHandler.behaviour_info(:optional_callbacks) |> Enum.sort()

      assert optional == ResourceHandler.callbacks()
    end

    test "every callback takes three arguments" do
      # The dispatcher asks `function_exported?(mod, callback, 3)` and applies
      # three arguments. A callback declared at any other arity would be
      # declared and never called.
      for {name, arity} <- ResourceHandler.callbacks() do
        assert arity == 3, "#{name}/#{arity} is declared but the dispatcher only calls arity 3"
      end
    end
  end

  describe "contract vs dispatcher" do
    test "every callback the dispatcher invokes is declared" do
      # The dispatcher names its callbacks in two places: directly at the
      # create/delete call sites, and through `reaction_callback/1`. Read them
      # out of the source rather than restating them, so adding a seventh
      # event without declaring it fails here.
      source = File.read!(@source)

      dispatched =
        Regex.scan(~r/:(on_comment_[a-z_]+)/, source)
        |> Enum.map(fn [_, name] -> String.to_atom(name) end)
        |> Enum.uniq()
        |> Enum.sort()

      declared = ResourceHandler.callbacks() |> Enum.map(&elem(&1, 0)) |> Enum.sort()

      assert dispatched == declared,
             """
             The dispatcher and the behaviour disagree.

               only dispatched: #{inspect(dispatched -- declared)}
               only declared:   #{inspect(declared -- dispatched)}

             A callback the dispatcher invokes but the behaviour does not
             declare gets no compile check, which is the failure this contract
             exists to prevent. One the behaviour declares but nothing invokes
             is a promise to a host that will never be kept.
             """
    end
  end

  describe "adopting it" do
    defmodule PartialHandler do
      @moduledoc false
      @behaviour PhoenixKitComments.ResourceHandler

      @impl true
      def on_comment_created(_type, _uuid, _comment), do: :handled
    end

    test "a handler may implement just one callback" do
      # Compiling this module at all is most of the test: if the callbacks
      # were not optional, `@behaviour` here would warn about five missing
      # implementations.
      assert PartialHandler.on_comment_created("post", "uuid", %{}) == :handled
      refute function_exported?(PartialHandler, :on_comment_deleted, 3)
    end

    test "the dispatcher's guard still governs what runs" do
      # Adopting the behaviour changes nothing at runtime — the guard is what
      # decides, exactly as it did before.
      assert function_exported?(PartialHandler, :on_comment_created, 3)
    end
  end
end
